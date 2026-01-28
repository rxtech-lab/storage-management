import { notFound } from "next/navigation";
import Link from "next/link";
import { Suspense } from "react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  ArrowLeft,
  Edit,
  Eye,
  EyeOff,
  MapPin,
  User,
  Tag,
  ExternalLink,
  Trash,
} from "lucide-react";
import { ItemForm } from "@/components/forms/item-form";
import { PositionForm } from "@/components/forms/position-form";
import { ContentForm } from "@/components/forms/content-form";
import { WhitelistForm } from "@/components/forms/whitelist-form";
import { ItemChildren } from "@/components/items/item-children";
import { QRCodeGenerator } from "@/components/items/qr-code-generator";
import { LocationDisplay } from "@/components/maps/location-display";
import {
  getItem,
  getItemChildren,
  deleteItemFormAction,
} from "@/lib/actions/item-actions";
import { getCategories } from "@/lib/actions/category-actions";
import { getLocations, getLocation } from "@/lib/actions/location-actions";
import { getAuthors } from "@/lib/actions/author-actions";
import { getPositionSchemas } from "@/lib/actions/position-schema-actions";
import { getItemPositions } from "@/lib/actions/position-actions";
import { getItemContents } from "@/lib/actions/content-actions";
import { getItemWhitelist } from "@/lib/actions/whitelist-actions";
import { formatDistanceToNow } from "date-fns";

interface ItemDetailPageProps {
  params: Promise<{ id: string }>;
}

export default async function ItemDetailPage({ params }: ItemDetailPageProps) {
  const { id } = await params;
  const itemId = parseInt(id);

  const item = await getItem(itemId);

  if (!item) {
    notFound();
  }

  const [
    categories,
    locations,
    authors,
    positionSchemas,
    positions,
    contents,
    whitelist,
    children,
  ] = await Promise.all([
    getCategories(),
    getLocations(),
    getAuthors(),
    getPositionSchemas(),
    getItemPositions(itemId),
    getItemContents(itemId),
    getItemWhitelist(itemId),
    getItemChildren(itemId),
  ]);

  const location = item.locationId ? await getLocation(item.locationId) : null;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link href="/items">
            <Button variant="ghost" size="icon">
              <ArrowLeft className="h-4 w-4" />
            </Button>
          </Link>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-3xl font-bold">{item.title}</h1>
              {item.visibility === "public" ? (
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
            <p className="text-muted-foreground">
              Last updated{" "}
              {formatDistanceToNow(new Date(item.updatedAt), {
                addSuffix: true,
              })}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <QRCodeGenerator itemId={item.id} itemTitle={item.title} />
          <Link href={`/preview/${item.id}`} target="_blank">
            <Button variant="outline" size="sm">
              <ExternalLink className="h-4 w-4 mr-2" />
              Preview
            </Button>
          </Link>
          <form action={deleteItemFormAction.bind(null, item.id)}>
            <Button variant="destructive" size="sm" type="submit">
              <Trash className="h-4 w-4 mr-2" />
              Delete
            </Button>
          </form>
        </div>
      </div>

      {/* Quick Info */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {item.category && (
          <Card>
            <CardContent className="pt-4">
              <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <Tag className="h-4 w-4" />
                Category
              </div>
              <p className="font-medium">{item.category.name}</p>
            </CardContent>
          </Card>
        )}
        {item.location && (
          <Card>
            <CardContent className="pt-4">
              <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <MapPin className="h-4 w-4" />
                Location
              </div>
              <p className="font-medium">{item.location.title}</p>
            </CardContent>
          </Card>
        )}
        {item.author && (
          <Card>
            <CardContent className="pt-4">
              <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <User className="h-4 w-4" />
                Author
              </div>
              <p className="font-medium">{item.author.name}</p>
            </CardContent>
          </Card>
        )}
        {item.price !== null && (
          <Card>
            <CardContent className="pt-4">
              <div className="text-sm text-muted-foreground">Price</div>
              <p className="font-medium text-lg">${item.price.toFixed(2)}</p>
            </CardContent>
          </Card>
        )}
      </div>

      <Tabs defaultValue="details" className="w-full">
        <TabsList>
          <TabsTrigger value="details">Details</TabsTrigger>
          <TabsTrigger value="position">Position</TabsTrigger>
          <TabsTrigger value="contents">
            Contents ({contents.length})
          </TabsTrigger>
          <TabsTrigger value="children">
            Children ({children.length})
          </TabsTrigger>
          {item.visibility === "private" && (
            <TabsTrigger value="whitelist">
              Whitelist ({whitelist.length})
            </TabsTrigger>
          )}
        </TabsList>

        <TabsContent value="details" className="space-y-6 mt-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div>
              <Suspense fallback={<div>Loading...</div>}>
                <ItemForm
                  item={item}
                  categories={categories}
                  locations={locations}
                  authors={authors}
                />
              </Suspense>
            </div>
            {location && (
              <div>
                <LocationDisplay
                  latitude={location.latitude}
                  longitude={location.longitude}
                  title={location.title}
                  height="400px"
                />
              </div>
            )}
          </div>
        </TabsContent>

        <TabsContent value="position" className="mt-6">
          <PositionForm
            itemId={item.id}
            positions={positions}
            positionSchemas={positionSchemas}
          />
        </TabsContent>

        <TabsContent value="contents" className="mt-6">
          <ContentForm itemId={item.id} contents={contents} />
        </TabsContent>

        <TabsContent value="children" className="mt-6">
          <ItemChildren children={children} parentId={item.id} />
        </TabsContent>

        {item.visibility === "private" && (
          <TabsContent value="whitelist" className="mt-6">
            <WhitelistForm itemId={item.id} whitelist={whitelist} />
          </TabsContent>
        )}
      </Tabs>
    </div>
  );
}
