import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Plus, Edit, Trash, User } from "lucide-react";
import {
  getAuthorsPaginated,
  deleteAuthorFormAction,
} from "@/lib/actions/author-actions";
import { formatDistanceToNow } from "date-fns";
import { PaginationNav } from "@/components/ui/pagination-nav";

const PAGE_SIZE = 20;

export default async function AuthorsPage({
  searchParams,
}: {
  searchParams: Promise<{ cursor?: string; direction?: string }>;
}) {
  const params = await searchParams;
  const cursor = params.cursor;
  const direction = (params.direction ?? "next") as "next" | "prev";

  const result = await getAuthorsPaginated(undefined, {
    cursor,
    direction,
    limit: PAGE_SIZE,
  });

  const authors = result.data;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Authors</h1>
          <p className="text-muted-foreground">
            Manage item authors and creators
          </p>
        </div>
        <Link href="/authors/new">
          <Button>
            <Plus className="h-4 w-4 mr-2" />
            New Author
          </Button>
        </Link>
      </div>

      {authors.length === 0 ? (
        <Card>
          <CardContent className="py-12 text-center">
            <p className="text-muted-foreground mb-4">No authors yet</p>
            <Link href="/authors/new">
              <Button>
                <Plus className="h-4 w-4 mr-2" />
                Create your first author
              </Button>
            </Link>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {authors.map((author) => (
            <Card key={author.id}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-lg flex items-center gap-2">
                  <User className="h-4 w-4 text-muted-foreground" />
                  {author.name}
                </CardTitle>
                <div className="flex gap-1">
                  <Link href={`/authors/${author.id}`}>
                    <Button variant="ghost" size="icon">
                      <Edit className="h-4 w-4" />
                    </Button>
                  </Link>
                  <form action={deleteAuthorFormAction.bind(null, author.id)}>
                    <Button variant="ghost" size="icon" type="submit">
                      <Trash className="h-4 w-4 text-destructive" />
                    </Button>
                  </form>
                </div>
              </CardHeader>
              <CardContent>
                {author.bio && (
                  <p className="text-sm text-muted-foreground line-clamp-2 mb-2">
                    {author.bio}
                  </p>
                )}
                <p className="text-xs text-muted-foreground">
                  Updated{" "}
                  {formatDistanceToNow(new Date(author.updatedAt), {
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
