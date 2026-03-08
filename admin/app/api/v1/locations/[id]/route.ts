import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getLocation, updateLocationAction, deleteLocationAction } from "@/lib/actions/location-actions";
import { getItemsPaginated } from "@/lib/actions/item-actions";
import { signImagesArrayWithIds } from "@/lib/actions/s3-upload-actions";
import { LocationDetailResponseSchema } from "@/lib/schemas/locations";

interface RouteParams {
  params: Promise<{ id: string }>;
}

/**
 * Get location by ID
 * @operationId getLocation
 * @description Retrieve a single location by its ID, including related items
 * @pathParams IdPathParams
 * @response LocationDetailResponseSchema
 * @auth bearer
 * @tag Locations
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const location = await getLocation(id);

  if (!location) {
    return NextResponse.json({ error: "Location not found" }, { status: 404 });
  }

  // Check ownership
  if (location.userId !== session.user.id) {
    return NextResponse.json({ error: "Permission denied" }, { status: 403 });
  }

  // Fetch related items (limited to 10)
  const itemsResult = await getItemsPaginated(session.user.id, {
    locationId: id,
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

  const response = LocationDetailResponseSchema.parse({
    ...location,
    items: itemsWithSignedImages,
    totalItems: itemsResult.pagination.totalCount,
  });

  return NextResponse.json(response);
}

/**
 * Update location
 * @operationId updateLocation
 * @description Update an existing location
 * @pathParams IdPathParams
 * @body LocationUpdateSchema
 * @response LocationResponseSchema
 * @auth bearer
 * @tag Locations
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
    const result = await updateLocationAction(id, body, session.user.id);

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
 * Delete location
 * @operationId deleteLocation
 * @description Delete a location by ID
 * @pathParams IdPathParams
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag Locations
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const result = await deleteLocationAction(id, session.user.id);

  if (result.success) {
    return NextResponse.json({ success: true });
  } else if (result.error === "Permission denied") {
    return NextResponse.json({ error: result.error }, { status: 403 });
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}
