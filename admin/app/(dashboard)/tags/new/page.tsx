import { TagForm } from "@/components/forms/tag-form";

export default function NewTagPage() {
  return (
    <div className="max-w-2xl">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">New Tag</h1>
        <p className="text-muted-foreground">Create a new item tag</p>
      </div>
      <TagForm />
    </div>
  );
}
