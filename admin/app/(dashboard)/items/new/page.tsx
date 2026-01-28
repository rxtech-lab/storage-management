import { Suspense } from "react";
import { ItemForm } from "@/components/forms/item-form";
import { getCategories } from "@/lib/actions/category-actions";
import { getLocations } from "@/lib/actions/location-actions";
import { getAuthors } from "@/lib/actions/author-actions";

interface NewItemPageProps {
  searchParams: Promise<{ parentId?: string }>;
}

export default async function NewItemPage({ searchParams }: NewItemPageProps) {
  const params = await searchParams;
  const [categories, locations, authors] = await Promise.all([
    getCategories(),
    getLocations(),
    getAuthors(),
  ]);

  const defaultParentId = params.parentId ? parseInt(params.parentId) : undefined;

  return (
    <div className="max-w-4xl">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">New Item</h1>
        <p className="text-muted-foreground">
          Create a new storage item
        </p>
      </div>

      <Suspense fallback={<div>Loading...</div>}>
        <ItemForm
          categories={categories}
          locations={locations}
          authors={authors}
          defaultParentId={defaultParentId}
        />
      </Suspense>
    </div>
  );
}
