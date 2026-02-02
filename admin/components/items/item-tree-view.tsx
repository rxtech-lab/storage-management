"use client";

import { useState } from "react";
import Link from "next/link";
import { ChevronRight, ChevronDown, Folder, FolderOpen, File, Eye, EyeOff } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import type { ItemWithRelations } from "@/lib/actions/item-actions";

interface TreeNode extends ItemWithRelations {
  children?: TreeNode[];
}

interface ItemTreeViewProps {
  items: ItemWithRelations[];
}

function buildTree(items: ItemWithRelations[]): TreeNode[] {
  const itemMap = new Map<number, TreeNode>();
  const roots: TreeNode[] = [];

  // First pass: create all nodes
  items.forEach((item) => {
    itemMap.set(item.id, { ...item, children: [] });
  });

  // Second pass: build tree structure
  items.forEach((item) => {
    const node = itemMap.get(item.id)!;
    if (item.parentId && itemMap.has(item.parentId)) {
      const parent = itemMap.get(item.parentId)!;
      parent.children = parent.children || [];
      parent.children.push(node);
    } else {
      roots.push(node);
    }
  });

  return roots;
}

function TreeNodeComponent({
  node,
  level = 0,
}: {
  node: TreeNode;
  level?: number;
}) {
  const [isExpanded, setIsExpanded] = useState(level < 2);
  const hasChildren = node.children && node.children.length > 0;

  return (
    <div>
      <div
        className={cn(
          "flex items-center gap-2 py-2 px-2 rounded-md hover:bg-muted/50 transition-colors group",
          level > 0 && "ml-4"
        )}
        style={{ paddingLeft: `${level * 16 + 8}px` }}
      >
        {hasChildren ? (
          <button
            onClick={() => setIsExpanded(!isExpanded)}
            className="p-0.5 hover:bg-muted rounded"
          >
            {isExpanded ? (
              <ChevronDown className="h-4 w-4" />
            ) : (
              <ChevronRight className="h-4 w-4" />
            )}
          </button>
        ) : (
          <span className="w-5" />
        )}

        {hasChildren ? (
          isExpanded ? (
            <FolderOpen className="h-4 w-4 text-amber-500" />
          ) : (
            <Folder className="h-4 w-4 text-amber-500" />
          )
        ) : (
          <File className="h-4 w-4 text-muted-foreground" />
        )}

        <Link
          href={`/items/${node.id}`}
          className="flex-1 flex items-center gap-2 hover:underline"
        >
          <span className="font-medium">{node.title}</span>
          {node.category && (
            <Badge variant="outline" className="text-xs">
              {node.category.name}
            </Badge>
          )}
        </Link>

        <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
          {node.visibility === "publicAccess" ? (
            <Eye className="h-4 w-4 text-green-500" />
          ) : (
            <EyeOff className="h-4 w-4 text-muted-foreground" />
          )}
        </div>
      </div>

      {isExpanded && hasChildren && (
        <div className="border-l ml-4">
          {node.children!.map((child) => (
            <TreeNodeComponent key={child.id} node={child} level={level + 1} />
          ))}
        </div>
      )}
    </div>
  );
}

export function ItemTreeView({ items }: ItemTreeViewProps) {
  const tree = buildTree(items);

  if (tree.length === 0) {
    return (
      <div className="text-center py-8 text-muted-foreground">
        No items found
      </div>
    );
  }

  return (
    <div className="border rounded-lg p-2">
      {tree.map((node) => (
        <TreeNodeComponent key={node.id} node={node} />
      ))}
    </div>
  );
}
