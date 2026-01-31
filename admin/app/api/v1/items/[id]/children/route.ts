import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getItemChildren } from "@/lib/actions/item-actions";
import { signImagesArray } from "@/lib/actions/s3-upload-actions";

interface RouteParams {
  params: Promise<{ id: string }>;
}

export async function GET(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const children = await getItemChildren(parseInt(id), session.user.id);

  // Sign images for each child item - replace file IDs with signed URLs
  const childrenWithSignedImages = await Promise.all(
    children.map(async (child) => {
      const images =
        child.images && child.images.length > 0
          ? await signImagesArray(child.images)
          : [];
      return {
        ...child,
        images,
        previewUrl: `${process.env.NEXT_PUBLIC_URL}/preview/${child.id}`,
      };
    }),
  );

  return NextResponse.json(childrenWithSignedImages);
}
