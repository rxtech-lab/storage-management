"use client";

import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { DeleteConfirmButton } from "@/components/ui/delete-confirm-button";
import { deleteItemAndRedirect } from "@/lib/actions/item-actions";

interface ItemDeleteButtonProps {
  itemId: number;
  itemTitle: string;
}

export function ItemDeleteButton({ itemId, itemTitle }: ItemDeleteButtonProps) {
  const router = useRouter();

  const handleDelete = async () => {
    const result = await deleteItemAndRedirect(itemId);
    if (result.success) {
      toast.success("Item deleted");
      router.push("/items");
    } else {
      toast.error(result.error || "Failed to delete item");
    }
  };

  return (
    <DeleteConfirmButton
      onConfirm={handleDelete}
      title={`Delete "${itemTitle}"?`}
      description="This action cannot be undone. This will permanently delete this item and all its associated positions, contents, and whitelist entries."
    />
  );
}
