import { NextResponse } from "next/server";
import { ItemAIRelationsRequestSchema, ItemAIRelationsResponseSchema } from "@/lib/schemas/item-ai";
import { eq, and } from "drizzle-orm";
import { db, categories, authors, tags } from "@/lib/db";
import { ensureSchemaInitialized } from "@/lib/db/client";
import { getSession } from "@/lib/auth-helper";

/**
 * Create or reuse selected item relation suggestions
 * @operationId createItemAIRelations
 * @body ItemAIRelationsRequestSchema
 * @response ItemAIRelationsResponseSchema
 * @auth bearer
 * @tag Items
 * @openapi
 */
export async function POST(request: Request) {
  const session = await getSession(request);
  if (!session?.user?.id) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  try {
    const input = ItemAIRelationsRequestSchema.parse(await request.json());
    await ensureSchemaInitialized();
    const userId = session.user.id;
    const result = await db.transaction(async tx => {
      let categoryId: string | null = null;
      let authorId: string | null = null;
      const tagIds: string[] = [];
      if (input.category) {
        const existing = await tx.select().from(categories).where(and(eq(categories.userId, userId), eq(categories.name, input.category))).limit(1);
        categoryId = existing[0]?.id ?? (await tx.insert(categories).values({ userId, name: input.category }).returning())[0].id;
      }
      if (input.author) {
        const existing = await tx.select().from(authors).where(and(eq(authors.userId, userId), eq(authors.name, input.author))).limit(1);
        authorId = existing[0]?.id ?? (await tx.insert(authors).values({ userId, name: input.author }).returning())[0].id;
      }
      for (const title of new Set(input.tags)) {
        const existing = await tx.select().from(tags).where(and(eq(tags.userId, userId), eq(tags.title, title))).limit(1);
        tagIds.push(existing[0]?.id ?? (await tx.insert(tags).values({ userId, title, color: "#3b82f6" }).returning())[0].id);
      }
      return { categoryId, authorId, tagIds };
    });
    return NextResponse.json(ItemAIRelationsResponseSchema.parse(result));
  } catch {
    return NextResponse.json({ error: "Could not create selected suggestions" }, { status: 400 });
  }
}
