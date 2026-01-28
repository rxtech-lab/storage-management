"use client";

import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { DeleteConfirmButton } from "@/components/ui/delete-confirm-button";
import { deletePositionSchemaAndRedirect } from "@/lib/actions/position-schema-actions";

interface PositionSchemaDeleteButtonProps {
  schemaId: number;
  schemaName: string;
}

export function PositionSchemaDeleteButton({
  schemaId,
  schemaName,
}: PositionSchemaDeleteButtonProps) {
  const router = useRouter();

  const handleDelete = async () => {
    const result = await deletePositionSchemaAndRedirect(schemaId);
    if (result.success) {
      toast.success("Position schema deleted");
      router.push("/position-schemas");
    } else {
      toast.error(result.error || "Failed to delete position schema");
    }
  };

  return (
    <DeleteConfirmButton
      onConfirm={handleDelete}
      title={`Delete "${schemaName}"?`}
      description="This action cannot be undone. This will permanently delete this position schema and may affect items using it."
    />
  );
}
