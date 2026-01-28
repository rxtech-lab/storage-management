import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import {
  getPositionSchema,
  updatePositionSchemaAction,
  deletePositionSchemaAction,
} from "@/lib/actions/position-schema-actions";

interface RouteParams {
  params: Promise<{ id: string }>;
}

export async function GET(request: NextRequest, { params }: RouteParams) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const schema = await getPositionSchema(parseInt(id));

  if (!schema) {
    return NextResponse.json({ error: "Position schema not found" }, { status: 404 });
  }

  return NextResponse.json({ data: schema });
}

export async function PUT(request: NextRequest, { params }: RouteParams) {
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;

  try {
    const body = await request.json();
    const result = await updatePositionSchemaAction(parseInt(id), body);

    if (result.success) {
      return NextResponse.json({ data: result.data });
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
  const session = await getSession();
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const result = await deletePositionSchemaAction(parseInt(id));

  if (result.success) {
    return NextResponse.json({ success: true });
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}
