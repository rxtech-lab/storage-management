import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { getIsoJobsPaginated } from "@/lib/actions/iso-job-actions";
import { IsoJobKind, IsoJobStatus } from "@/lib/schemas/iso-jobs";
import { parsePaginationParams } from "@/lib/utils/pagination";

/**
 * List ISO jobs
 * @operationId getIsoJobs
 * @description Retrieve a paginated list of ISO generation and burning jobs reported by the iso-burner CLI, newest first
 * @params IsoJobsQueryParams
 * @response PaginatedIsoJobsResponse
 * @auth bearer
 * @tag IsoJobs
 * @responseSet auth
 * @openapi
 */
export async function GET(request: NextRequest) {
  const session = await getSession(request);
  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const searchParams = request.nextUrl.searchParams;
  const kind = IsoJobKind.safeParse(searchParams.get("kind"));
  const status = IsoJobStatus.safeParse(searchParams.get("status"));
  const paginationParams = parsePaginationParams({
    cursor: searchParams.get("cursor"),
    direction: searchParams.get("direction"),
    limit: searchParams.get("limit"),
  });

  const result = await getIsoJobsPaginated(session.user.id, {
    ...paginationParams,
    kind: kind.success ? kind.data : undefined,
    status: status.success ? status.data : undefined,
  });

  return NextResponse.json({
    data: result.data,
    pagination: result.pagination,
  });
}
