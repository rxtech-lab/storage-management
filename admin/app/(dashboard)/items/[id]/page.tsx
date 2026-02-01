import { notFound } from "next/navigation";
import { ItemPageClient } from "./item-page-client";
import { getItem, getItemChildren } from "@/lib/actions/item-actions";
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
    positionSchemas,
    positions,
    contents,
    whitelist,
    children,
  ] = await Promise.all([
    getPositionSchemas(),
    getItemPositions(itemId),
    getItemContents(itemId),
    getItemWhitelist(itemId),
    getItemChildren(itemId),
  ]);

  return (
    <ItemPageClient
      item={item}
      positionSchemas={positionSchemas}
      positions={positions}
      contents={contents}
      whitelist={whitelist}
      childItems={children}
    />
  );
}
