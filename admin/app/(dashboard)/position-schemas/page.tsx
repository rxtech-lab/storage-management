import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Plus, Edit, Trash, FileJson } from "lucide-react";
import {
  getPositionSchemasPaginated,
  deletePositionSchemaFormAction,
} from "@/lib/actions/position-schema-actions";
import { formatDistanceToNow } from "date-fns";
import { PaginationNav } from "@/components/ui/pagination-nav";

const PAGE_SIZE = 20;

export default async function PositionSchemasPage({
  searchParams,
}: {
  searchParams: Promise<{ cursor?: string; direction?: string }>;
}) {
  const params = await searchParams;
  const cursor = params.cursor;
  const direction = (params.direction ?? "next") as "next" | "prev";

  const result = await getPositionSchemasPaginated(undefined, {
    cursor,
    direction,
    limit: PAGE_SIZE,
  });

  const schemas = result.data;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Position Schemas</h1>
          <p className="text-muted-foreground">
            Define schemas for item positioning
          </p>
        </div>
        <Link href="/position-schemas/new">
          <Button data-testid="position-schemas-new-button">
            <Plus className="h-4 w-4 mr-2" />
            New Schema
          </Button>
        </Link>
      </div>

      {schemas.length === 0 ? (
        <Card data-testid="position-schemas-empty-state">
          <CardContent className="py-12 text-center">
            <p className="text-muted-foreground mb-4">No position schemas yet</p>
            <Link href="/position-schemas/new">
              <Button>
                <Plus className="h-4 w-4 mr-2" />
                Create your first schema
              </Button>
            </Link>
          </CardContent>
        </Card>
      ) : (
        <div
          className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
          data-testid="position-schemas-grid"
        >
          {schemas.map((schema) => {
            const schemaObj = schema.schema as {
              properties?: Record<string, unknown>;
            };
            const fieldCount = schemaObj.properties
              ? Object.keys(schemaObj.properties).length
              : 0;

            return (
              <Card
                key={schema.id}
                data-testid={`position-schema-card-${schema.id}`}
              >
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-lg flex items-center gap-2">
                    <FileJson className="h-4 w-4 text-muted-foreground" />
                    {schema.name}
                  </CardTitle>
                  <div className="flex gap-1">
                    <Link href={`/position-schemas/${schema.id}`}>
                      <Button
                        variant="ghost"
                        size="icon"
                        data-testid={`position-schema-edit-button-${schema.id}`}
                      >
                        <Edit className="h-4 w-4" />
                      </Button>
                    </Link>
                    <form
                      action={deletePositionSchemaFormAction.bind(
                        null,
                        schema.id
                      )}
                    >
                      <Button
                        variant="ghost"
                        size="icon"
                        type="submit"
                        data-testid={`position-schema-delete-button-${schema.id}`}
                      >
                        <Trash className="h-4 w-4 text-destructive" />
                      </Button>
                    </form>
                  </div>
                </CardHeader>
                <CardContent>
                  <p className="text-sm text-muted-foreground mb-2">
                    {fieldCount} field{fieldCount !== 1 ? "s" : ""}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    Updated{" "}
                    {formatDistanceToNow(new Date(schema.updatedAt), {
                      addSuffix: true,
                    })}
                  </p>
                </CardContent>
              </Card>
            );
          })}
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
