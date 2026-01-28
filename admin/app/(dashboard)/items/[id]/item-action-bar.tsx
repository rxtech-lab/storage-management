"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Edit, ExternalLink } from "lucide-react";
import { QRCodeGenerator } from "@/components/items/qr-code-generator";
import { ItemDeleteButton } from "@/components/items/item-delete-button";

interface ItemActionBarProps {
  itemId: number;
  itemTitle: string;
}

export function ItemActionBar({ itemId, itemTitle }: ItemActionBarProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const isEditing = searchParams.get("edit") === "true";

  const handleEditClick = () => {
    router.push(`/items/${itemId}?edit=true`);
  };

  return (
    <div className="flex items-center gap-2">
      {!isEditing && (
        <Button variant="outline" size="sm" className="gap-2" onClick={handleEditClick}>
          <Edit className="h-4 w-4" />
          Edit
        </Button>
      )}
      <QRCodeGenerator itemId={itemId} itemTitle={itemTitle} />
      <Link href={`/preview/${itemId}`} target="_blank">
        <Button variant="outline" size="sm" className="gap-2">
          <ExternalLink className="h-4 w-4" />
          Preview
        </Button>
      </Link>
      <ItemDeleteButton itemId={itemId} itemTitle={itemTitle} />
    </div>
  );
}
