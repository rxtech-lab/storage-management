import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { setItemParent } from "@/lib/actions/item-actions";
import { signImagesArrayWithIds } from "@/lib/actions/s3-upload-actions";

interface RouteParams {
  params: Promise<{ id: string }>;
}

// PUT /api/v1/items/[id]/parent - Set or remove parent
// Body: { parentId: number | null }
export async function PUT(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;

  try {
    const body = await request.json();
    const parentId = body.parentId as number | null;

    const result = await setItemParent(
      parseInt(id),
      parentId,
      session.user.id
    );

    if (result.success && result.data) {
      const previewUrl = `${process.env.NEXT_PUBLIC_URL}/preview/item/${result.data.id}`;

      // Sign images - replace file IDs with signed URLs
      const images =
        result.data.images && result.data.images.length > 0
          ? await signImagesArrayWithIds(result.data.images)
          : [];

      return NextResponse.json({ ...result.data, images, previewUrl });
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
