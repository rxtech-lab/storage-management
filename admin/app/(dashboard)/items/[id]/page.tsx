import { notFound } from "next/navigation";
import { HeroMap } from "@/components/maps/hero-map";
import { BackButton } from "./back-button";
import { ItemActionBar } from "./item-action-bar";
import { ItemDetailClient } from "./item-detail-client";
import { getItem, getItemChildren } from "@/lib/actions/item-actions";
import { getCategories } from "@/lib/actions/category-actions";
import { getLocations, getLocation } from "@/lib/actions/location-actions";
import { getAuthors } from "@/lib/actions/author-actions";
import { getPositionSchemas } from "@/lib/actions/position-schema-actions";
import { getItemPositions } from "@/lib/actions/position-actions";
import { getItemContents } from "@/lib/actions/content-actions";
import { getItemWhitelist } from "@/lib/actions/whitelist-actions";

interface ItemDetailPageProps {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ edit?: string }>;
}

export default async function ItemDetailPage({
  params,
  searchParams,
}: ItemDetailPageProps) {
  const { id } = await params;
  const { edit } = await searchParams;
  const itemId = parseInt(id);
  const isEditing = edit === "true";

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
      {/* Sticky Top Bar */}
      <div className="sticky -top-5 z-50 flex items-center justify-between">
        <BackButton />
        <ItemActionBar itemId={item.id} itemTitle={item.title} />
      </div>

      {/* Hero Map */}
      <HeroMap
        latitude={location?.latitude}
        longitude={location?.longitude}
        title={location?.title}
      />

      {/* Item Details - Client Component for edit mode toggle */}
      <ItemDetailClient
        item={item}
        categories={categories}
        locations={locations}
        authors={authors}
        positionSchemas={positionSchemas}
        positions={positions}
        contents={contents}
        whitelist={whitelist}
        childItems={children}
        isEditing={isEditing}
      />
    </div>
  );
}
