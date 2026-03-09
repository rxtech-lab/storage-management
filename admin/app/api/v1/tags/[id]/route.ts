import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getTag, updateTagAction, deleteTagAction } from "@/lib/actions/tag-actions";
import { getItemsPaginated } from "@/lib/actions/item-actions";
import { signImagesArrayWithIds } from "@/lib/actions/s3-upload-actions";
import { TagDetailResponseSchema } from "@/lib/schemas/tags";

interface RouteParams {
  params: Promise<{ id: string }>;
}

/**
 * Get tag by ID
 * @operationId getTag
 * @description Retrieve a single tag by its ID, including related items
 * @pathParams IdPathParams
 * @response TagDetailResponseSchema
 * @auth bearer
 * @tag Tags
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const tag = await getTag(id);

  if (!tag) {
    return NextResponse.json({ error: "Tag not found" }, { status: 404 });
  }

  if (tag.userId !== session.user.id) {
    return NextResponse.json({ error: "Permission denied" }, { status: 403 });
  }

  // Fetch related items (limited to 10)
  const itemsResult = await getItemsPaginated(session.user.id, {
    tagIds: [id],
    limit: 10,
  });

  // Sign images for each item
  const itemsWithSignedImages = await Promise.all(
    itemsResult.data.map(async (item) => {
      const images =
        item.images && item.images.length > 0
          ? await signImagesArrayWithIds(item.images)
          : [];
      return {
        ...item,
        images,
        previewUrl: `${process.env.NEXT_PUBLIC_URL}/preview/item?id=${item.id}`,
      };
    })
  );

  const response = TagDetailResponseSchema.parse({
    ...tag,
    items: itemsWithSignedImages,
    totalItems: itemsResult.pagination.totalCount,
  });

  return NextResponse.json(response);
}

/**
 * Update tag
 * @operationId updateTag
 * @description Update an existing tag
 * @pathParams IdPathParams
 * @body TagUpdateSchema
 * @response TagResponseSchema
 * @auth bearer
 * @tag Tags
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
    const result = await updateTagAction(id, body, session.user.id);

    if (result.success) {
      return NextResponse.json(result.data);
    } else if (result.error === "Permission denied") {
      return NextResponse.json({ error: result.error }, { status: 403 });
    } else {
      return NextResponse.json({ error: result.error }, { status: 400 });
    }
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Invalid request" },
      { status: 400 }
    );
  }
}

/**
 * Delete tag
 * @operationId deleteTag
 * @description Delete a tag by ID
 * @pathParams IdPathParams
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag Tags
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const result = await deleteTagAction(id, session.user.id);

  if (result.success) {
    return NextResponse.json({ success: true });
  } else if (result.error === "Permission denied") {
    return NextResponse.json({ error: result.error }, { status: 403 });
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}
