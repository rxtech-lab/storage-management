import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import {
  getIsoJob,
  upsertIsoJobAction,
  deleteIsoJobAction,
} from "@/lib/actions/iso-job-actions";

interface RouteParams {
  params: Promise<{ id: string }>;
}

/**
 * Get ISO job by ID
 * @operationId getIsoJob
 * @description Retrieve an ISO job with its per-ISO and per-drive progress rows
 * @pathParams IdPathParams
 * @response IsoJobDetailResponseSchema
 * @auth bearer
 * @tag IsoJobs
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const job = await getIsoJob(id);
  if (!job) {
    return NextResponse.json({ error: "ISO job not found" }, { status: 404 });
  }
  if (job.userId !== session.user.id) {
    return NextResponse.json({ error: "Permission denied" }, { status: 403 });
  }

  return NextResponse.json(job);
}

/**
 * Report ISO job progress
 * @operationId upsertIsoJob
 * @description Create or replace an ISO job from a progress snapshot. The iso-burner CLI chooses the job ID and sends the full job state, including every progress row, on each report.
 * @pathParams IdPathParams
 * @body IsoJobUpsertSchema
 * @response IsoJobDetailResponseSchema
 * @auth bearer
 * @tag IsoJobs
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
    const result = await upsertIsoJobAction(id, body, session.user.id);

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
 * Delete ISO job
 * @operationId deleteIsoJob
 * @description Delete an ISO job and its progress rows
 * @pathParams IdPathParams
 * @response 200:SuccessResponse
 * @auth bearer
 * @tag IsoJobs
 * @responseSet auth
 * @openapi
 */
export async function DELETE(request: NextRequest, { params }: RouteParams) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await params;
  const result = await deleteIsoJobAction(id, session.user.id);

  if (result.success) {
    return NextResponse.json({ success: true });
  } else if (result.error === "Permission denied") {
    return NextResponse.json({ error: result.error }, { status: 403 });
  } else if (result.error === "ISO job not found") {
    return NextResponse.json({ error: result.error }, { status: 404 });
  } else {
    return NextResponse.json({ error: result.error }, { status: 400 });
  }
}
