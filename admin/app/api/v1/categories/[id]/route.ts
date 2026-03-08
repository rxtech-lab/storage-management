import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getCategory, updateCategoryAction, deleteCategoryAction } from "@/lib/actions/category-actions";
import { getItemsPaginated } from "@/lib/actions/item-actions";
import { signImagesArrayWithIds } from "@/lib/actions/s3-upload-actions";
import { CategoryDetailResponseSchema } from "@/lib/schemas/categories";

interface RouteParams {
  params: Promise<{ id: string }>;
}

/**
 * Get category by ID
 * @operationId getCategory
 * @description Retrieve a single category by its ID, including related items
 * @pathParams IdPathParams
 * @response CategoryDetailResponseSchema
 * @auth bearer
 * @tag Categories
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const category = await getCategory(id);

  if (!category) {
    return NextResponse.json({ error: "Category not found" }, { status: 404 });
  }

  // Check ownership
  if (category.userId !== session.user.id) {
    return NextResponse.json({ error: "Permission denied" }, { status: 403 });
  }

  // Fetch related items (limited to 10)
  const itemsResult = await getItemsPaginated(session.user.id, {
    categoryId: id,
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

  const response = CategoryDetailResponseSchema.parse({
    ...category,
    items: itemsWithSignedImages,
    totalItems: itemsResult.pagination.totalCount,
  });

  return NextResponse.json(response);
}

/**
 * Update category
 * @operationId updateCategory
 * @description Update an existing category
 * @pathParams IdPathParams
 * @body CategoryUpdateSchema
 * @response CategoryResponseSchema
 * @auth bearer
 * @tag Categories
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
    const result = await updateCategoryAction(id, body, session.user.id);

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
 * Delete category
 * @operationId deleteCategory
 * @description Delete a category by ID
 * @pathParams IdPathParams
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag Categories
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const result = await deleteCategoryAction(id, session.user.id);

  if (result.success) {
    return NextResponse.json({ success: true });
  } else if (result.error === "Permission denied") {
    return NextResponse.json({ error: result.error }, { status: 403 });
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}
