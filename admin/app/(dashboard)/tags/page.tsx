import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Plus, Edit, Trash } from "lucide-react";
import {
  getTagsPaginated,
  deleteTagFormAction,
} from "@/lib/actions/tag-actions";
import { formatDistanceToNow } from "date-fns";
import { PaginationNav } from "@/components/ui/pagination-nav";

const PAGE_SIZE = 20;

export default async function TagsPage({
  searchParams,
}: {
  searchParams: Promise<{ cursor?: string; direction?: string }>;
}) {
  const params = await searchParams;
  const cursor = params.cursor;
  const direction = (params.direction ?? "next") as "next" | "prev";

  const result = await getTagsPaginated(undefined, {
    cursor,
    direction,
    limit: PAGE_SIZE,
  });

  const tags = result.data;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Tags</h1>
          <p className="text-muted-foreground">Manage item tags</p>
        </div>
        <Link href="/tags/new">
          <Button>
            <Plus className="h-4 w-4 mr-2" />
            New Tag
          </Button>
        </Link>
      </div>

      {tags.length === 0 ? (
        <Card>
          <CardContent className="py-12 text-center">
            <p className="text-muted-foreground mb-4">No tags yet</p>
            <Link href="/tags/new">
              <Button>
                <Plus className="h-4 w-4 mr-2" />
                Create your first tag
              </Button>
            </Link>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {tags.map((tag) => (
            <Card key={tag.id}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <div className="flex items-center gap-2">
                  <div
                    className="h-4 w-4 rounded-full"
                    style={{ backgroundColor: tag.color }}
                  />
                  <CardTitle className="text-lg">{tag.title}</CardTitle>
                </div>
                <div className="flex gap-1">
                  <Link href={`/tags/${tag.id}`}>
                    <Button variant="ghost" size="icon">
                      <Edit className="h-4 w-4" />
                    </Button>
                  </Link>
                  <form action={deleteTagFormAction.bind(null, tag.id)}>
                    <Button variant="ghost" size="icon" type="submit">
                      <Trash className="h-4 w-4 text-destructive" />
                    </Button>
                  </form>
                </div>
              </CardHeader>
              <CardContent>
                <div className="flex items-center gap-2">
                  <span
                    className="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium"
                    style={{
                      backgroundColor: tag.color,
                      color: isLightColor(tag.color) ? "#000" : "#fff",
                    }}
                  >
                    {tag.title}
                  </span>
                </div>
                <p className="text-xs text-muted-foreground mt-2">
                  Updated{" "}
                  {formatDistanceToNow(new Date(tag.updatedAt), {
                    addSuffix: true,
                  })}
                </p>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      <PaginationNav
        nextCursor={result.pagination.nextCursor}
        prevCursor={result.pagination.prevCursor}
        hasNextPage={result.pagination.hasNextPage}
        hasPrevPage={result.pagination.hasPrevPage}
      />
    </div>
  );
}

function isLightColor(hex: string): boolean {
  const color = hex.replace("#", "");
  if (color.length !== 6) return true;
  const r = parseInt(color.substring(0, 2), 16) / 255;
  const g = parseInt(color.substring(2, 4), 16) / 255;
  const b = parseInt(color.substring(4, 6), 16) / 255;
  const luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  return luminance > 0.5;
}
