import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getAuthors, createAuthorAction, type AuthorFilters } from "@/lib/actions/author-actions";

export async function GET(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const searchParams = request.nextUrl.searchParams;
  const filters: AuthorFilters = {};

  if (searchParams.has("search")) {
    filters.search = searchParams.get("search")!;
  }
  if (searchParams.has("limit")) {
    filters.limit = parseInt(searchParams.get("limit")!);
  }

  const authors = await getAuthors(session.user.id, Object.keys(filters).length > 0 ? filters : undefined);
  return NextResponse.json(authors);
}

export async function POST(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const body = await request.json();
    const result = await createAuthorAction(body, session.user.id);

    if (result.success) {
      return NextResponse.json(result.data, { status: 201 });
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
