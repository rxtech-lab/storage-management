import { AuthorForm } from "@/components/forms/author-form";

export default function NewAuthorPage() {
  return (
    <div className="max-w-2xl mx-auto">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">New Author</h1>
        <p className="text-muted-foreground">
          Add a new author or creator
        </p>
      </div>
      <AuthorForm />
    </div>
  );
}
