import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getCategories, createCategoryAction } from "@/lib/actions/category-actions";

export async function GET() {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const categories = await getCategories();
  return NextResponse.json({ data: categories });
}

export async function POST(request: NextRequest) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const body = await request.json();
    const result = await createCategoryAction(body);

    if (result.success) {
      return NextResponse.json({ data: result.data }, { status: 201 });
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
