import { Suspense } from "react";
import { ItemForm } from "@/components/forms/item-form";
import { getPositionSchemas } from "@/lib/actions/position-schema-actions";

interface NewItemPageProps {
  searchParams: Promise<{ parentId?: string }>;
}

export default async function NewItemPage({ searchParams }: NewItemPageProps) {
  const params = await searchParams;
  const positionSchemas = await getPositionSchemas();

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
          positionSchemas={positionSchemas}
          defaultParentId={defaultParentId}
        />
      </Suspense>
    </div>
  );
}
