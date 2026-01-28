import { notFound } from "next/navigation";
import { AuthorForm } from "@/components/forms/author-form";
import { getAuthor } from "@/lib/actions/author-actions";

interface EditAuthorPageProps {
  params: Promise<{ id: string }>;
}

export default async function EditAuthorPage({ params }: EditAuthorPageProps) {
  const { id } = await params;
  const author = await getAuthor(parseInt(id));

  if (!author) {
    notFound();
  }

  return (
    <div className="max-w-2xl mx-auto">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">Edit Author</h1>
        <p className="text-muted-foreground">
          Update author details
        </p>
      </div>
      <AuthorForm author={author} />
    </div>
  );
}
