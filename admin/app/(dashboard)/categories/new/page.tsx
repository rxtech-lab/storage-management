import { CategoryForm } from "@/components/forms/category-form";

export default function NewCategoryPage() {
  return (
    <div className="max-w-2xl">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">New Category</h1>
        <p className="text-muted-foreground">
          Create a new item category
        </p>
      </div>
      <CategoryForm />
    </div>
  );
}
