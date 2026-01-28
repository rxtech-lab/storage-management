import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Package, FolderTree, MapPin, User, Plus, Eye, EyeOff } from "lucide-react";
import { getItems } from "@/lib/actions/item-actions";
import { getCategories } from "@/lib/actions/category-actions";
import { getLocations } from "@/lib/actions/location-actions";
import { getAuthors } from "@/lib/actions/author-actions";
import { formatDistanceToNow } from "date-fns";

export default async function DashboardPage() {
  const [items, categories, locations, authors] = await Promise.all([
    getItems(),
    getCategories(),
    getLocations(),
    getAuthors(),
  ]);

  const publicItems = items.filter((i) => i.visibility === "public");
  const privateItems = items.filter((i) => i.visibility === "private");
  const recentItems = items.slice(0, 5);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Dashboard</h1>
          <p className="text-muted-foreground">
            Overview of your storage management
          </p>
        </div>
        <Link href="/items/new">
          <Button>
            <Plus className="h-4 w-4 mr-2" />
            New Item
          </Button>
        </Link>
      </div>

      {/* Stats Cards */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Items</CardTitle>
            <Package className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{items.length}</div>
            <p className="text-xs text-muted-foreground">
              {publicItems.length} public, {privateItems.length} private
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Categories</CardTitle>
            <FolderTree className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{categories.length}</div>
            <Link href="/categories" className="text-xs text-muted-foreground hover:underline">
              Manage categories
            </Link>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Locations</CardTitle>
            <MapPin className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{locations.length}</div>
            <Link href="/locations" className="text-xs text-muted-foreground hover:underline">
              Manage locations
            </Link>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Authors</CardTitle>
            <User className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{authors.length}</div>
            <Link href="/authors" className="text-xs text-muted-foreground hover:underline">
              Manage authors
            </Link>
          </CardContent>
        </Card>
      </div>

      {/* Recent Items */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>Recent Items</CardTitle>
          <Link href="/items">
            <Button variant="ghost" size="sm">View all</Button>
          </Link>
        </CardHeader>
        <CardContent>
          {recentItems.length === 0 ? (
            <div className="text-center py-8">
              <p className="text-muted-foreground mb-4">No items yet</p>
              <Link href="/items/new">
                <Button>
                  <Plus className="h-4 w-4 mr-2" />
                  Create your first item
                </Button>
              </Link>
            </div>
          ) : (
            <div className="space-y-4">
              {recentItems.map((item) => (
                <Link
                  key={item.id}
                  href={`/items/${item.id}`}
                  className="flex items-center justify-between p-3 rounded-lg border hover:bg-muted/50 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-muted">
                      <Package className="h-5 w-5 text-muted-foreground" />
                    </div>
                    <div>
                      <p className="font-medium">{item.title}</p>
                      <div className="flex items-center gap-2 text-xs text-muted-foreground">
                        {item.category && <span>{item.category.name}</span>}
                        {item.category && item.location && <span>•</span>}
                        {item.location && <span>{item.location.title}</span>}
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    {item.visibility === "public" ? (
                      <Eye className="h-4 w-4 text-green-500" />
                    ) : (
                      <EyeOff className="h-4 w-4 text-muted-foreground" />
                    )}
                    <span className="text-xs text-muted-foreground">
                      {formatDistanceToNow(new Date(item.updatedAt), { addSuffix: true })}
                    </span>
                  </div>
                </Link>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Quick Actions */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Link href="/items/new">
          <Card className="hover:bg-muted/50 transition-colors cursor-pointer">
            <CardContent className="pt-6">
              <div className="flex items-center gap-3">
                <Package className="h-8 w-8 text-primary" />
                <div>
                  <p className="font-medium">Add Item</p>
                  <p className="text-sm text-muted-foreground">Create a new storage item</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </Link>

        <Link href="/categories/new">
          <Card className="hover:bg-muted/50 transition-colors cursor-pointer">
            <CardContent className="pt-6">
              <div className="flex items-center gap-3">
                <FolderTree className="h-8 w-8 text-primary" />
                <div>
                  <p className="font-medium">Add Category</p>
                  <p className="text-sm text-muted-foreground">Organize your items</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </Link>

        <Link href="/locations/new">
          <Card className="hover:bg-muted/50 transition-colors cursor-pointer">
            <CardContent className="pt-6">
              <div className="flex items-center gap-3">
                <MapPin className="h-8 w-8 text-primary" />
                <div>
                  <p className="font-medium">Add Location</p>
                  <p className="text-sm text-muted-foreground">Add a storage location</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </Link>

        <Link href="/authors/new">
          <Card className="hover:bg-muted/50 transition-colors cursor-pointer">
            <CardContent className="pt-6">
              <div className="flex items-center gap-3">
                <User className="h-8 w-8 text-primary" />
                <div>
                  <p className="font-medium">Add Author</p>
                  <p className="text-sm text-muted-foreground">Add item creator</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </Link>
      </div>
    </div>
  );
}
