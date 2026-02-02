"use client";

import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import {
  Eye,
  EyeOff,
  Tag,
  User,
  DollarSign,
  Calendar,
  Box,
} from "lucide-react";
import { useSignedImages, getSignedUrl } from "@/lib/hooks/use-signed-images";
import { formatDistanceToNow } from "date-fns";
import type { ItemWithRelations } from "@/lib/actions/item-actions";

interface ItemDetailViewProps {
  item: ItemWithRelations;
}

export function ItemDetailView({ item }: ItemDetailViewProps) {
  const { signedUrls } = useSignedImages(item.images ?? []);

  return (
    <div className="space-y-6">
      {/* Header: Title */}
      <div className="space-y-1">
        <div className="flex items-center gap-3">
          <h1 className="text-3xl font-bold tracking-tight">{item.title}</h1>
          {item.visibility === "publicAccess" ? (
            <Badge variant="default" className="gap-1">
              <Eye className="h-3 w-3" />
              Public
            </Badge>
          ) : (
            <Badge variant="secondary" className="gap-1">
              <EyeOff className="h-3 w-3" />
              Private
            </Badge>
          )}
        </div>
        {item.originalQrCode && (
          <p className="text-sm text-muted-foreground">
            QR: {item.originalQrCode}
          </p>
        )}
      </div>

      {/* Metadata Pills */}
      <div className="flex gap-2 overflow-x-auto pb-2 -mb-2 scrollbar-hide">
        {item.category && (
          <div className="flex-shrink-0 flex items-center gap-2 px-3 py-1.5 rounded-full bg-secondary/80 border border-border/50">
            <Tag className="h-3.5 w-3.5 text-muted-foreground" />
            <span className="text-sm font-medium">{item.category.name}</span>
          </div>
        )}
        {item.author && (
          <div className="flex-shrink-0 flex items-center gap-2 px-3 py-1.5 rounded-full bg-secondary/80 border border-border/50">
            <User className="h-3.5 w-3.5 text-muted-foreground" />
            <span className="text-sm font-medium">{item.author.name}</span>
          </div>
        )}
        {item.price !== null && (
          <div className="flex-shrink-0 flex items-center gap-2 px-3 py-1.5 rounded-full bg-secondary/80 border border-border/50">
            <DollarSign className="h-3.5 w-3.5 text-muted-foreground" />
            <span className="text-sm font-medium">
              {item.currency || "USD"} {item.price.toFixed(2)}
            </span>
          </div>
        )}
        {item.parent && (
          <Link href={`/items/${item.parent.id}`}>
            <div className="shrink-0 flex items-center gap-2 px-3 py-1.5 rounded-full bg-secondary/80 border border-border/50 hover:bg-secondary transition-colors cursor-pointer">
              <Box className="h-3.5 w-3.5 text-muted-foreground" />
              <span className="text-sm font-medium">{item.parent.title}</span>
            </div>
          </Link>
        )}
        <div className="shrink-0 flex items-center gap-2 px-3 py-1.5 rounded-full bg-secondary/80 border border-border/50">
          <Calendar className="h-3.5 w-3.5 text-muted-foreground" />
          <span className="text-sm">
            {formatDistanceToNow(new Date(item.updatedAt), { addSuffix: true })}
          </span>
        </div>
      </div>

      {/* Images */}
      {item.images && item.images.length > 0 && (
        <div className="space-y-2 mt-3">
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            {item.images.map((image, index) => (
              <div
                key={index}
                className="relative aspect-square rounded-lg overflow-hidden bg-muted"
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={getSignedUrl(signedUrls, image)}
                  alt={`${item.title} - Image ${index + 1}`}
                  className="absolute inset-0 h-full w-full object-cover"
                />
                {index === 0 && (
                  <span className="absolute bottom-2 left-2 bg-primary text-primary-foreground text-xs px-2 py-1 rounded">
                    Main
                  </span>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Description */}
      {item.description && (
        <div className="space-y-2 mt-2 border rounded-xl px-2 py-2">
          <label className="text-sm text-slate-500 font-bold">
            Description
          </label>
          <p className="text-muted-foreground leading-relaxed whitespace-pre-wrap">
            {item.description}
          </p>
        </div>
      )}
    </div>
  );
}
