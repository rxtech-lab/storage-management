import { NextRequest, NextResponse } from "next/server";
import { auth } from "@/auth";
import { getItemChildren } from "@/lib/actions/item-actions";

interface RouteParams {
  params: Promise<{ id: string }>;
}

export async function GET(request: NextRequest, { params }: RouteParams) {
  const session = await auth();
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const children = await getItemChildren(parseInt(id));

  return NextResponse.json({ data: children });
}
