import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import {
  getItems,
  createItemAction,
  type ItemFilters,
} from "@/lib/actions/item-actions";
import { signImagesArray } from "@/lib/actions/s3-upload-actions";

export async function GET(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const searchParams = request.nextUrl.searchParams;
  const filters: ItemFilters = {
    userId: session.user.id,
  };

  if (searchParams.has("categoryId")) {
    filters.categoryId = parseInt(searchParams.get("categoryId")!);
  }
  if (searchParams.has("locationId")) {
    filters.locationId = parseInt(searchParams.get("locationId")!);
  }
  if (searchParams.has("authorId")) {
    filters.authorId = parseInt(searchParams.get("authorId")!);
  }
  if (searchParams.has("parentId")) {
    const parentId = searchParams.get("parentId");
    filters.parentId = parentId === "null" ? null : parseInt(parentId!);
  }
  if (searchParams.has("visibility")) {
    filters.visibility = searchParams.get("visibility") as "public" | "private";
  }
  if (searchParams.has("search")) {
    filters.search = searchParams.get("search")!;
  }

  const items = await getItems(session.user.id, filters);

  // Sign images for each item - replace file IDs with signed URLs
  const itemsWithSignedImages = await Promise.all(
    items.map(async (item) => {
      const images =
        item.images && item.images.length > 0
          ? await signImagesArray(item.images)
          : [];
      return {
        ...item,
        images,
        previewUrl: `${process.env.NEXT_PUBLIC_URL}/preview/${item.id}`,
      };
    }),
  );

  return NextResponse.json(itemsWithSignedImages);
}

export async function POST(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const body = await request.json();
    const result = await createItemAction(body, session.user.id);

    if (result.success && result.data) {
      // Sign images - replace file IDs with signed URLs
      const images =
        result.data.images && result.data.images.length > 0
          ? await signImagesArray(result.data.images)
          : [];

      const previewUrl = `${process.env.NEXT_PUBLIC_URL}/preview/${result.data.id}`;
      return NextResponse.json(
        { ...result.data, images, previewUrl },
        { status: 201 },
      );
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
