import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getLocation, updateLocationAction, deleteLocationAction } from "@/lib/actions/location-actions";

interface RouteParams {
  params: Promise<{ id: string }>;
}

/**
 * Get location by ID
 * @operationId getLocation
 * @description Retrieve a single location by its ID
 * @pathParams IdPathParams
 * @response LocationResponseSchema
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
  const location = await getLocation(parseInt(id));

  if (!location) {
    return NextResponse.json({ error: "Location not found" }, { status: 404 });
  }

  // Check ownership
  if (location.userId !== session.user.id) {
    return NextResponse.json({ error: "Permission denied" }, { status: 403 });
  }

  return NextResponse.json(location);
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
    const result = await updateLocationAction(parseInt(id), body, session.user.id);

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
  const result = await deleteLocationAction(parseInt(id), session.user.id);

  if (result.success) {
    return NextResponse.json({ success: true });
  } else if (result.error === "Permission denied") {
    return NextResponse.json({ error: result.error }, { status: 403 });
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}
