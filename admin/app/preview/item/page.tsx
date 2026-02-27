import { redirect, notFound } from "next/navigation";

interface PreviewItemPageProps {
  searchParams: Promise<{ id?: string }>;
}

export default async function PreviewItemPage({
  searchParams,
}: PreviewItemPageProps) {
  const { id } = await searchParams;

  if (!id) {
    notFound();
  }

  const itemId = parseInt(id);
  if (isNaN(itemId)) {
    notFound();
  }

  redirect(`/preview/item/${itemId}`);
}
