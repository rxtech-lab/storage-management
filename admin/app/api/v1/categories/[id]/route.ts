import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getCategory, updateCategoryAction, deleteCategoryAction } from "@/lib/actions/category-actions";

interface RouteParams {
  params: Promise<{ id: string }>;
}

export async function GET(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const category = await getCategory(parseInt(id));

  if (!category) {
    return NextResponse.json({ error: "Category not found" }, { status: 404 });
  }

  // Check ownership
  if (category.userId !== session.user.id) {
    return NextResponse.json({ error: "Permission denied" }, { status: 403 });
  }

  return NextResponse.json({ data: category });
}

export async function PUT(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;

  try {
    const body = await request.json();
    const result = await updateCategoryAction(parseInt(id), body, session.user.id);

    if (result.success) {
      return NextResponse.json({ data: result.data });
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

export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const result = await deleteCategoryAction(parseInt(id), session.user.id);

  if (result.success) {
    return NextResponse.json({ success: true });
  } else if (result.error === "Permission denied") {
    return NextResponse.json({ error: result.error }, { status: 403 });
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}
