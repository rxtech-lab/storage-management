import { notFound } from "next/navigation";
import { TagForm } from "@/components/forms/tag-form";
import { getTag } from "@/lib/actions/tag-actions";

interface EditTagPageProps {
  params: Promise<{ id: string }>;
}

export default async function EditTagPage({ params }: EditTagPageProps) {
  const { id } = await params;
  const tag = await getTag(id);

  if (!tag) {
    notFound();
  }

  return (
    <div className="max-w-2xl">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">Edit Tag</h1>
        <p className="text-muted-foreground">Update tag details</p>
      </div>
      <TagForm tag={tag} />
    </div>
  );
}
