"use client";

import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Plus, ExternalLink, Eye, EyeOff } from "lucide-react";
import type { ItemWithRelations } from "@/lib/actions/item-actions";

interface ItemChildrenProps {
  children: ItemWithRelations[];
  parentId: number;
}

export function ItemChildren({ children, parentId }: ItemChildrenProps) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle className="text-lg">Child Items ({children.length})</CardTitle>
        <Link href={`/items/new?parentId=${parentId}`}>
          <Button size="sm">
            <Plus className="h-4 w-4 mr-2" />
            Add Child
          </Button>
        </Link>
      </CardHeader>
      <CardContent>
        {children.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-4">
            No child items yet. Click &quot;Add Child&quot; to create one.
          </p>
        ) : (
          <div className="space-y-2">
            {children.map((child) => (
              <Link
                key={child.id}
                href={`/items/${child.id}`}
                className="flex items-center justify-between p-3 rounded-lg border hover:bg-muted/50 transition-colors"
              >
                <div className="flex items-center gap-3">
                  <div>
                    <p className="font-medium">{child.title}</p>
                    {child.description && (
                      <p className="text-sm text-muted-foreground line-clamp-1">
                        {child.description}
                      </p>
                    )}
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  {child.category && (
                    <Badge variant="secondary">{child.category.name}</Badge>
                  )}
                  {child.visibility === "public" ? (
                    <Eye className="h-4 w-4 text-green-500" />
                  ) : (
                    <EyeOff className="h-4 w-4 text-muted-foreground" />
                  )}
                  <ExternalLink className="h-4 w-4 text-muted-foreground" />
                </div>
              </Link>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
