"use client";

import { useRouter, usePathname, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { ChevronLeft, ChevronRight } from "lucide-react";

interface PaginationNavProps {
  nextCursor: string | null;
  prevCursor: string | null;
  hasNextPage: boolean;
  hasPrevPage: boolean;
}

export function PaginationNav({
  nextCursor,
  prevCursor,
  hasNextPage,
  hasPrevPage,
}: PaginationNavProps) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const navigate = (cursor: string | null, direction: "next" | "prev") => {
    const params = new URLSearchParams(searchParams.toString());

    if (cursor) {
      params.set("cursor", cursor);
      params.set("direction", direction);
    } else {
      params.delete("cursor");
      params.delete("direction");
    }

    router.push(`${pathname}?${params.toString()}`);
  };

  // Don't render if there's only one page
  if (!hasNextPage && !hasPrevPage) {
    return null;
  }

  return (
    <div className="flex items-center justify-center gap-4 py-4">
      <Button
        variant="outline"
        size="sm"
        onClick={() => navigate(prevCursor, "prev")}
        disabled={!hasPrevPage}
      >
        <ChevronLeft className="h-4 w-4 mr-1" />
        Previous
      </Button>
      <Button
        variant="outline"
        size="sm"
        onClick={() => navigate(nextCursor, "next")}
        disabled={!hasNextPage}
      >
        Next
        <ChevronRight className="h-4 w-4 ml-1" />
      </Button>
    </div>
  );
}
