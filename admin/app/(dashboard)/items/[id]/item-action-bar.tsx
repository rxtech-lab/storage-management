"use client";

import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Edit, ExternalLink } from "lucide-react";
import { QRCodeGenerator } from "@/components/items/qr-code-generator";
import { ItemDeleteButton } from "@/components/items/item-delete-button";

interface ItemActionBarProps {
  itemId: number;
  itemTitle: string;
  onEditClick: () => void;
}

export function ItemActionBar({
  itemId,
  itemTitle,
  onEditClick,
}: ItemActionBarProps) {
  return (
    <div className="flex items-center gap-2">
      <Button
        variant="outline"
        size="sm"
        className="gap-2"
        onClick={onEditClick}
      >
        <Edit className="h-4 w-4" />
        Edit
      </Button>
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
