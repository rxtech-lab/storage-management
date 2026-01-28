import { notFound } from "next/navigation";
import { CategoryForm } from "@/components/forms/category-form";
import { getCategory } from "@/lib/actions/category-actions";

interface EditCategoryPageProps {
  params: Promise<{ id: string }>;
}

export default async function EditCategoryPage({ params }: EditCategoryPageProps) {
  const { id } = await params;
  const category = await getCategory(parseInt(id));

  if (!category) {
    notFound();
  }

  return (
    <div className="max-w-2xl">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">Edit Category</h1>
        <p className="text-muted-foreground">
          Update category details
        </p>
      </div>
      <CategoryForm category={category} />
    </div>
  );
}
