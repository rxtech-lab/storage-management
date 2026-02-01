/**
 * Cursor-based pagination utilities
 *
 * Cursor encoding format: Base64 JSON with sortValue + id for stable ordering
 * - Items: sorted by updatedAt DESC, id DESC
 * - Simple entities: sorted by name/title ASC, id ASC
 */

export interface CursorValue {
  /** The value of the sort column (updatedAt timestamp or name/title string) */
  sortValue: string | number;
  /** The row ID for tie-breaking when sort values are equal */
  id: number;
}

export interface PaginationParams {
  /** Base64 encoded cursor for current position */
  cursor?: string;
  /** Navigation direction: 'next' for forward, 'prev' for backward */
  direction?: "next" | "prev";
  /** Number of items per page (default: 20) */
  limit?: number;
}

export interface PaginationInfo {
  /** Cursor to use for next page navigation */
  nextCursor: string | null;
  /** Cursor to use for previous page navigation */
  prevCursor: string | null;
  /** Whether there are more items after the current page */
  hasNextPage: boolean;
  /** Whether there are items before the current page */
  hasPrevPage: boolean;
}

export interface PaginatedResult<T> {
  data: T[];
  pagination: PaginationInfo;
}

export const DEFAULT_PAGE_SIZE = 20;

/**
 * Encode a cursor value to a URL-safe Base64 string
 */
export function encodeCursor(value: CursorValue): string {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

/**
 * Decode a Base64 cursor string back to its original value
 * Returns null if the cursor is invalid
 */
export function decodeCursor(cursor: string): CursorValue | null {
  try {
    const decoded = Buffer.from(cursor, "base64url").toString("utf-8");
    const parsed = JSON.parse(decoded);

    // Validate the structure
    if (
      typeof parsed === "object" &&
      parsed !== null &&
      "sortValue" in parsed &&
      "id" in parsed &&
      typeof parsed.id === "number"
    ) {
      return parsed as CursorValue;
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * Build a paginated response from query results
 *
 * @param data - The fetched data (should be limit + 1 items to check for more)
 * @param limit - The requested page size
 * @param direction - The navigation direction
 * @param getSortValue - Function to extract the sort value from an item
 * @param hasCursor - Whether a cursor was provided (to determine hasPrevPage on first page)
 */
export function buildPaginatedResponse<T extends { id: number }>(
  data: T[],
  limit: number,
  direction: "next" | "prev",
  getSortValue: (item: T) => string | number,
  hasCursor: boolean
): PaginatedResult<T> {
  // Check if we have more items than requested
  const hasMore = data.length > limit;

  // Trim to requested limit
  const trimmedData = hasMore ? data.slice(0, limit) : data;

  // For 'prev' direction, we fetched in reverse order, so reverse back
  const finalData = direction === "prev" ? trimmedData.reverse() : trimmedData;

  // Determine pagination flags
  let hasNextPage: boolean;
  let hasPrevPage: boolean;

  if (direction === "next") {
    // Going forward: hasMore means there's a next page
    // hasPrevPage is true if we had a cursor (not first page)
    hasNextPage = hasMore;
    hasPrevPage = hasCursor;
  } else {
    // Going backward: hasMore means there's a previous page
    // hasNextPage is true since we came from a next page
    hasNextPage = true;
    hasPrevPage = hasMore;
  }

  // Build cursors from the first and last items
  let nextCursor: string | null = null;
  let prevCursor: string | null = null;

  if (finalData.length > 0) {
    const firstItem = finalData[0];
    const lastItem = finalData[finalData.length - 1];

    if (hasNextPage) {
      nextCursor = encodeCursor({
        sortValue: getSortValue(lastItem),
        id: lastItem.id,
      });
    }

    if (hasPrevPage) {
      prevCursor = encodeCursor({
        sortValue: getSortValue(firstItem),
        id: firstItem.id,
      });
    }
  }

  return {
    data: finalData,
    pagination: {
      nextCursor,
      prevCursor,
      hasNextPage,
      hasPrevPage,
    },
  };
}

/**
 * Parse pagination parameters from a URL search params or request
 */
export function parsePaginationParams(params: {
  cursor?: string | null;
  direction?: string | null;
  limit?: string | null;
}): PaginationParams {
  return {
    cursor: params.cursor ?? undefined,
    direction:
      params.direction === "prev" || params.direction === "next"
        ? params.direction
        : "next",
    limit: params.limit ? parseInt(params.limit, 10) : DEFAULT_PAGE_SIZE,
  };
}
