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
import { signImagesArrayWithIds } from "@/lib/actions/s3-upload-actions";
import { isEmailWhitelisted } from "@/lib/actions/whitelist-actions";
import {
  ItemDetailResponseSchema,
  ItemResponseSchema,
} from "@/lib/schemas/items";
import { stat } from "fs";

interface RouteParams {
  params: Promise<{ id: string }>;
}

/**
 * Get item by ID
 * @operationId getItem
 * @description Retrieve detailed item information including children, contents, and positions. Public items can be accessed without authentication.
 * @pathParams IdPathParams
 * @response ItemDetailResponseSchema
 * @tag Items
 * @responseSet public
 * @openapi
 */
export async function GET(request: NextRequest, { params }: RouteParams) {
  const { id } = await params;
  const itemId = parseInt(id);
  const item = await getItem(itemId);

  if (!item) {
    return NextResponse.json({ error: "Item not found" }, { status: 404 });
  }

  // Public items can be accessed without authentication
  if (item.visibility === "publicAccess") {
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
        return NextResponse.json(
          { error: "Permission denied" },
          { status: 403 },
        );
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
  userId: string | null,
) {
  const previewUrl = `${process.env.NEXT_PUBLIC_URL}/preview/item/${item.id}`;

  // Fetch item images, children, contents, and positions in parallel
  const [images, children, contents, positions] = await Promise.all([
    item.images && item.images.length > 0
      ? signImagesArrayWithIds(item.images)
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
          ? await signImagesArrayWithIds(child.images)
          : [];
      return {
        ...child,
        images: childImages,
        previewUrl: `${process.env.NEXT_PUBLIC_URL}/preview/item/${child.id}`,
      };
    }),
  );

  const responseData = {
    ...item,
    images,
    previewUrl,
    children: childrenWithSignedImages,
    contents,
    positions,
  };

  const validated = ItemDetailResponseSchema.safeParse(responseData);
  if (!validated.success) {
    console.error("Validation error:", validated.error.errors);
    return NextResponse.json(
      { error: "Invalid response data" },
      { status: 500 },
    );
  }
  return NextResponse.json(validated.data);
}

/**
 * Update item
 * @operationId updateItem
 * @description Update an existing item
 * @pathParams IdPathParams
 * @body ItemUpdateSchema
 * @response ItemResponseSchema
 * @auth bearer
 * @tag Items
 * @responseSet auth
 * @openapi
 */
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
          ? await signImagesArrayWithIds(result.data.images)
          : [];

      const responseData = { ...result.data, images, previewUrl };
      const validated = ItemResponseSchema.parse(responseData);
      return NextResponse.json(validated);
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

/**
 * Delete item
 * @operationId deleteItem
 * @description Delete an item by ID
 * @pathParams IdPathParams
 * @response 204:NoContent
 * @auth bearer
 * @tag Items
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const result = await deleteItemAction(parseInt(id), session.user.id);

  if (result.success) {
    return new NextResponse(null, { status: 204 });
  } else if (result.error === "Permission denied") {
    return NextResponse.json({ error: result.error }, { status: 403 });
  } else if (result.error === "Item not found") {
    return NextResponse.json({ error: result.error }, { status: 404 });
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}
