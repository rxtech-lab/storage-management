import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getAuthor, updateAuthorAction, deleteAuthorAction } from "@/lib/actions/author-actions";
import { getItemsPaginated } from "@/lib/actions/item-actions";
import { signImagesArrayWithIds } from "@/lib/actions/s3-upload-actions";
import { AuthorDetailResponseSchema } from "@/lib/schemas/authors";

interface RouteParams {
  params: Promise<{ id: string }>;
}

/**
 * Get author by ID
 * @operationId getAuthor
 * @description Retrieve a single author by its ID, including related items
 * @pathParams IdPathParams
 * @response AuthorDetailResponseSchema
 * @auth bearer
 * @tag Authors
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const author = await getAuthor(id);

  if (!author) {
    return NextResponse.json({ error: "Author not found" }, { status: 404 });
  }

  // Check ownership
  if (author.userId !== session.user.id) {
    return NextResponse.json({ error: "Permission denied" }, { status: 403 });
  }

  // Fetch related items (limited to 10)
  const itemsResult = await getItemsPaginated(session.user.id, {
    authorId: id,
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

  const response = AuthorDetailResponseSchema.parse({
    ...author,
    items: itemsWithSignedImages,
    totalItems: itemsResult.pagination.totalCount,
  });

  return NextResponse.json(response);
}

/**
 * Update author
 * @operationId updateAuthor
 * @description Update an existing author
 * @pathParams IdPathParams
 * @body AuthorUpdateSchema
 * @response AuthorResponseSchema
 * @auth bearer
 * @tag Authors
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
    const result = await updateAuthorAction(id, body, session.user.id);

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
 * Delete author
 * @operationId deleteAuthor
 * @description Delete an author by ID
 * @pathParams IdPathParams
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag Authors
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const result = await deleteAuthorAction(id, session.user.id);

  if (result.success) {
    return NextResponse.json({ success: true });
  } else if (result.error === "Permission denied") {
    return NextResponse.json({ error: result.error }, { status: 403 });
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}
