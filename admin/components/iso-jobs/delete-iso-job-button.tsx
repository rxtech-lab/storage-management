"use client";

import { useRouter } from "next/navigation";
import { DeleteConfirmButton } from "@/components/ui/delete-confirm-button";
import { deleteIsoJobAction } from "@/lib/actions/iso-job-actions";

export function DeleteIsoJobButton({ id, title }: { id: string; title: string }) {
  const router = useRouter();
  return (
    <DeleteConfirmButton
      title="Delete ISO job"
      description={`Delete the progress history of "${title}"? The ISO files and discs are not affected.`}
      onConfirm={async () => {
        const result = await deleteIsoJobAction(id);
        if (result.success) {
          router.push("/iso-jobs");
        }
      }}
    />
  );
}
