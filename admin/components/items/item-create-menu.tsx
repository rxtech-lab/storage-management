"use client";
import Link from "next/link";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem } from "@/components/ui/dropdown-menu";

export function ItemCreateMenu({ parentId }: { parentId?: string }) {
  const query = parentId ? `&parentId=${encodeURIComponent(parentId)}` : "";
  return <DropdownMenu>
    <DropdownMenuTrigger asChild><Button data-testid="items-new-button"><Plus className="h-4 w-4 mr-2" />New Item</Button></DropdownMenuTrigger>
    <DropdownMenuContent align="end">
      <DropdownMenuItem asChild><Link href={`/items/new?mode=form${query}`}>Create using form</Link></DropdownMenuItem>
      <DropdownMenuItem asChild><Link href={`/items/new?mode=ai${query}`}>Create using AI</Link></DropdownMenuItem>
    </DropdownMenuContent>
  </DropdownMenu>;
}
