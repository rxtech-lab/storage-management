import { and, eq, isNotNull, isNull } from "drizzle-orm";
import { db, items, itemStocks } from "@/lib/db";
import { deleteFilesForItem } from "@/lib/actions/file-actions";

export async function purgeItem(id: string, userId: string) {
 const condition = and(eq(items.id,id),eq(items.userId,userId),isNotNull(items.deletedAt));
 const [item] = await db.select().from(items).where(condition).limit(1);
 if (!item) throw new Error("Deleted item not found");
 // Keep surviving children; remove only the selected deleted item.
 await db.transaction(async tx => {
   await tx.update(items).set({parentId:null}).where(and(eq(items.parentId,id),eq(items.userId,userId)));
   await tx.update(itemStocks).set({parentId:null}).where(and(eq(itemStocks.parentId,id),eq(itemStocks.userId,userId)));
 });
 const result = await deleteFilesForItem(id, true);
 if (!result.success) throw new Error(result.error || "Could not delete files");
 await db.delete(items).where(condition);
}
export async function restoreItem(id:string,userId:string) {
 const [item] = await db.select().from(items).where(and(eq(items.id,id),eq(items.userId,userId),isNotNull(items.deletedAt))).limit(1);
 if (!item) throw new Error("Deleted item not found");
 const [parent] = item.parentId ? await db.select().from(items).where(and(eq(items.id,item.parentId),eq(items.userId,userId),isNull(items.deletedAt))) : [];
 await db.update(items).set({deletedAt:null,parentId:parent?.id ?? null,updatedAt:new Date()}).where(and(eq(items.id,id),eq(items.userId,userId)));
}
