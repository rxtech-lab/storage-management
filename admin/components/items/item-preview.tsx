"use client";

import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Eye, EyeOff, MapPin, User, Tag, ExternalLink } from "lucide-react";
import { formatDistanceToNow } from "date-fns";
import type { ItemWithRelations } from "@/lib/actions/item-actions";
import { useSignedImages, getSignedUrl } from "@/lib/hooks/use-signed-images";

interface ItemPreviewProps {
  item: ItemWithRelations;
  view: "grid" | "list";
}

export function ItemPreview({ item, view }: ItemPreviewProps) {
  const imageUrls = item.images && item.images.length > 0 ? [item.images[0]] : [];
  const { signedUrls } = useSignedImages(imageUrls);
  const thumbnailUrl = item.images?.[0] ? getSignedUrl(signedUrls, item.images[0]) : null;

  if (view === "list") {
    return (
      <Link href={`/items/${item.id}`}>
        <div className="flex items-center justify-between p-4 rounded-lg border hover:bg-muted/50 transition-colors">
          <div className="flex items-center gap-4">
            {thumbnailUrl ? (
              <img
                src={thumbnailUrl}
                alt={item.title}
                className="w-16 h-16 object-cover rounded-md"
              />
            ) : (
              <div className="w-16 h-16 bg-muted rounded-md flex items-center justify-center">
                <Tag className="h-6 w-6 text-muted-foreground" />
              </div>
            )}
            <div>
              <h3 className="font-medium">{item.title}</h3>
              {item.description && (
                <p className="text-sm text-muted-foreground line-clamp-1">
                  {item.description}
                </p>
              )}
              <div className="flex items-center gap-2 mt-1 text-xs text-muted-foreground">
                {item.category && (
                  <span className="flex items-center gap-1">
                    <Tag className="h-3 w-3" />
                    {item.category.name}
                  </span>
                )}
                {item.location && (
                  <span className="flex items-center gap-1">
                    <MapPin className="h-3 w-3" />
                    {item.location.title}
                  </span>
                )}
                {item.author && (
                  <span className="flex items-center gap-1">
                    <User className="h-3 w-3" />
                    {item.author.name}
                  </span>
                )}
              </div>
            </div>
          </div>
          <div className="flex items-center gap-3">
            {item.price !== null && (
              <Badge variant="secondary">${item.price.toFixed(2)}</Badge>
            )}
            {item.visibility === "public" ? (
              <Eye className="h-4 w-4 text-green-500" />
            ) : (
              <EyeOff className="h-4 w-4 text-muted-foreground" />
            )}
            <ExternalLink className="h-4 w-4 text-muted-foreground" />
          </div>
        </div>
      </Link>
    );
  }

  return (
    <Link href={`/items/${item.id}`}>
      <Card className="hover:shadow-lg transition-shadow h-full">
        <CardHeader className="p-0">
          {thumbnailUrl ? (
            <img
              src={thumbnailUrl}
              alt={item.title}
              className="w-full h-40 object-cover rounded-t-lg"
            />
          ) : (
            <div className="w-full h-40 bg-muted rounded-t-lg flex items-center justify-center">
              <Tag className="h-12 w-12 text-muted-foreground" />
            </div>
          )}
        </CardHeader>
        <CardContent className="p-4">
          <div className="flex items-start justify-between gap-2">
            <CardTitle className="text-lg line-clamp-1">{item.title}</CardTitle>
            {item.visibility === "public" ? (
              <Eye className="h-4 w-4 text-green-500 flex-shrink-0" />
            ) : (
              <EyeOff className="h-4 w-4 text-muted-foreground flex-shrink-0" />
            )}
          </div>
          {item.description && (
            <p className="text-sm text-muted-foreground mt-1 line-clamp-2">
              {item.description}
            </p>
          )}
          <div className="flex flex-wrap gap-1 mt-2">
            {item.category && (
              <Badge variant="secondary" className="text-xs">
                {item.category.name}
              </Badge>
            )}
            {item.price !== null && (
              <Badge variant="outline" className="text-xs">
                ${item.price.toFixed(2)}
              </Badge>
            )}
          </div>
        </CardContent>
        <CardFooter className="p-4 pt-0 text-xs text-muted-foreground">
          <div className="flex items-center gap-4">
            {item.location && (
              <span className="flex items-center gap-1">
                <MapPin className="h-3 w-3" />
                {item.location.title}
              </span>
            )}
            {item.author && (
              <span className="flex items-center gap-1">
                <User className="h-3 w-3" />
                {item.author.name}
              </span>
            )}
          </div>
          <span className="ml-auto">
            {formatDistanceToNow(new Date(item.updatedAt), { addSuffix: true })}
          </span>
        </CardFooter>
      </Card>
    </Link>
  );
}
