import { notFound } from "next/navigation";
import { ItemPageClient } from "./item-page-client";
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
}

export default async function ItemDetailPage({
  params,
}: ItemDetailPageProps) {
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

  const location = item.locationId ? (await getLocation(item.locationId)) ?? null : null;

  return (
    <ItemPageClient
      item={item}
      categories={categories}
      locations={locations}
      authors={authors}
      positionSchemas={positionSchemas}
      positions={positions}
      contents={contents}
      whitelist={whitelist}
      childItems={children}
      location={location}
    />
  );
}
