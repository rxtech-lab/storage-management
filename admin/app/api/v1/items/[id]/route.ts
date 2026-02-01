import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import {
  getItem,
  getItemChildren,
  updateItemAction,
  deleteItemAction,
} from "@/lib/actions/item-actions";
import { getItemContents } from "@/lib/actions/content-actions";
import { getItemPositions } from "@/lib/actions/position-actions";
import { signImagesArray } from "@/lib/actions/s3-upload-actions";
import { isEmailWhitelisted } from "@/lib/actions/whitelist-actions";

interface RouteParams {
  params: Promise<{ id: string }>;
}

export async function GET(request: NextRequest, { params }: RouteParams) {
  const { id } = await params;
  const itemId = parseInt(id);
  const item = await getItem(itemId);

  if (!item) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }

  // Public items can be accessed without authentication
  if (item.visibility === "public") {
    return buildItemResponse(item, itemId, null);
  }

  // Private items require authentication
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  // Check permission: owner can always see their items
  if (item.userId !== session.user.id) {
    // Check if user's email is whitelisted for this item
    if (session.user.email) {
      const whitelisted = await isEmailWhitelisted(itemId, session.user.email);
      if (!whitelisted) {
        return NextResponse.json({ error: "Permission denied" }, { status: 403 });
      }
    } else {
      // No email means no whitelist access possible
      return NextResponse.json({ error: "Permission denied" }, { status: 403 });
    }
  }

  return buildItemResponse(item, itemId, session.user.id);
}

async function buildItemResponse(
  item: NonNullable<Awaited<ReturnType<typeof getItem>>>,
  itemId: number,
  userId: string | null
) {
  const previewUrl = `${process.env.NEXT_PUBLIC_URL}/preview/item/${item.id}`;

  // Fetch item images, children, contents, and positions in parallel
  const [images, children, contents, positions] = await Promise.all([
    item.images && item.images.length > 0
      ? signImagesArray(item.images)
      : Promise.resolve([]),
    getItemChildren(itemId, userId ?? undefined),
    getItemContents(itemId),
    getItemPositions(itemId),
  ]);

  // Sign images for each child
  const childrenWithSignedImages = await Promise.all(
    children.map(async (child) => {
      const childImages =
        child.images && child.images.length > 0
          ? await signImagesArray(child.images)
          : [];
      return {
        ...child,
        images: childImages,
        previewUrl: `${process.env.NEXT_PUBLIC_URL}/preview/item/${child.id}`,
      };
    }),
  );

  return NextResponse.json({
    ...item,
    images,
    previewUrl,
    children: childrenWithSignedImages,
    contents,
    positions,
  });
}

export async function PUT(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;

  try {
    const body = await request.json();
    const result = await updateItemAction(parseInt(id), body, session.user.id);

    if (result.success && result.data) {
      const previewUrl = `${process.env.NEXT_PUBLIC_URL}/preview/item/${result.data.id}`;

      // Sign images - replace file IDs with signed URLs
      const images =
        result.data.images && result.data.images.length > 0
          ? await signImagesArray(result.data.images)
          : [];

      return NextResponse.json({ ...result.data, images, previewUrl });
    } else if (result.error === "Permission denied") {
      return NextResponse.json({ error: result.error }, { status: 403 });
    } else {
      return NextResponse.json({ error: result.error }, { status: 400 });
    }
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Invalid request" },
      { status: 400 },
    );
  }
}

export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const result = await deleteItemAction(parseInt(id), session.user.id);

  if (result.success) {
    return NextResponse.json({ success: true });
  } else if (result.error === "Permission denied") {
    return NextResponse.json({ error: result.error }, { status: 403 });
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}
