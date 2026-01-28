import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Plus, Edit, Trash } from "lucide-react";
import { getCategories, deleteCategoryFormAction } from "@/lib/actions/category-actions";
import { formatDistanceToNow } from "date-fns";

export default async function CategoriesPage() {
  const categories = await getCategories();

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Categories</h1>
          <p className="text-muted-foreground">
            Manage item categories
          </p>
        </div>
        <Link href="/categories/new">
          <Button>
            <Plus className="h-4 w-4 mr-2" />
            New Category
          </Button>
        </Link>
      </div>

      {categories.length === 0 ? (
        <Card>
          <CardContent className="py-12 text-center">
            <p className="text-muted-foreground mb-4">No categories yet</p>
            <Link href="/categories/new">
              <Button>
                <Plus className="h-4 w-4 mr-2" />
                Create your first category
              </Button>
            </Link>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {categories.map((category) => (
            <Card key={category.id}>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-lg">{category.name}</CardTitle>
                <div className="flex gap-1">
                  <Link href={`/categories/${category.id}`}>
                    <Button variant="ghost" size="icon">
                      <Edit className="h-4 w-4" />
                    </Button>
                  </Link>
                  <form action={deleteCategoryFormAction.bind(null, category.id)}>
                    <Button variant="ghost" size="icon" type="submit">
                      <Trash className="h-4 w-4 text-destructive" />
                    </Button>
                  </form>
                </div>
              </CardHeader>
              <CardContent>
                {category.description && (
                  <p className="text-sm text-muted-foreground line-clamp-2 mb-2">
                    {category.description}
                  </p>
                )}
                <p className="text-xs text-muted-foreground">
                  Updated {formatDistanceToNow(new Date(category.updatedAt), { addSuffix: true })}
                </p>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
