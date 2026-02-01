import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Plus, Edit, Trash, MapPin } from "lucide-react";
import {
  getLocationsPaginated,
  deleteLocationFormAction,
} from "@/lib/actions/location-actions";
import { formatDistanceToNow } from "date-fns";
import { PaginationNav } from "@/components/ui/pagination-nav";

const PAGE_SIZE = 20;

export default async function LocationsPage({
  searchParams,
}: {
  searchParams: Promise<{ cursor?: string; direction?: string }>;
}) {
  const params = await searchParams;
  const cursor = params.cursor;
  const direction = (params.direction ?? "next") as "next" | "prev";

  const result = await getLocationsPaginated(undefined, {
    cursor,
    direction,
    limit: PAGE_SIZE,
  });

  const locations = result.data;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Locations</h1>
          <p className="text-muted-foreground">Manage storage locations</p>
        </div>
        <Link href="/locations/new">
          <Button>
            <Plus className="h-4 w-4 mr-2" />
            New Location
          </Button>
        </Link>
      </div>

      {locations.length === 0 ? (
        <Card>
          <CardContent className="py-12 text-center">
            <p className="text-muted-foreground mb-4">No locations yet</p>
            <Link href="/locations/new">
              <Button>
                <Plus className="h-4 w-4 mr-2" />
                Create your first location
              </Button>
            </Link>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {locations.map((location) => (
            <Card key={location.id}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-lg flex items-center gap-2">
                  <MapPin className="h-4 w-4 text-muted-foreground" />
                  {location.title}
                </CardTitle>
                <div className="flex gap-1">
                  <Link href={`/locations/${location.id}`}>
                    <Button variant="ghost" size="icon">
                      <Edit className="h-4 w-4" />
                    </Button>
                  </Link>
                  <form
                    action={deleteLocationFormAction.bind(null, location.id)}
                  >
                    <Button variant="ghost" size="icon" type="submit">
                      <Trash className="h-4 w-4 text-destructive" />
                    </Button>
                  </form>
                </div>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground mb-2">
                  {location.latitude.toFixed(6)}, {location.longitude.toFixed(6)}
                </p>
                <p className="text-xs text-muted-foreground">
                  Updated{" "}
                  {formatDistanceToNow(new Date(location.updatedAt), {
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
