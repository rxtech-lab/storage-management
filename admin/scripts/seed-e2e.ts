import { db } from "../lib/db";
import { items } from "../lib/db/schema/items";
import { categories } from "../lib/db/schema/categories";
import { locations } from "../lib/db/schema/locations";
import { authors } from "../lib/db/schema/authors";
import { tags } from "../lib/db/schema/tags";
import { itemTags } from "../lib/db/schema/item-tags";

const TEST_USER_ID = "b8da73c7-eb56-46a2-a20a-385d298dfa97";

async function seed() {
  console.log("Seeding test data...");

  // Seed category
  const seededCategories = await db
    .insert(categories)
    .values([
      {
        id: "test-category-1",
        userId: TEST_USER_ID,
        name: "Test Category",
        description: "A test category for E2E testing",
      },
    ])
    .returning();

  // Seed location
  const seededLocations = await db
    .insert(locations)
    .values([
      {
        id: "test-location-1",
        userId: TEST_USER_ID,
        title: "Test Location",
        latitude: 37.7749,
        longitude: -122.4194,
      },
    ])
    .returning();

  // Seed author
  const seededAuthors = await db
    .insert(authors)
    .values([
      {
        id: "test-author-1",
        userId: TEST_USER_ID,
        name: "Test Author",
        bio: "A test author for E2E testing",
      },
    ])
    .returning();

  // Seed items
  const seededItems = await db
    .insert(items)
    .values([
      {
        id: "test-public-item",
        userId: TEST_USER_ID, // test user
        title: "Public Test Item",
        description: "This is a public test item for E2E testing",
        visibility: "publicAccess",
        categoryId: "test-category-1",
        locationId: "test-location-1",
        authorId: "test-author-1",
      },
      {
        id: "test-private-item",
        userId: TEST_USER_ID, // test user
        title: "Private Test Item",
        description: "This is a private test item for E2E testing",
        visibility: "privateAccess",
      },
      {
        id: "test-other-user-item",
        userId: "different-id", // different user for access control testing
        title: "Another User's Item",
        description: "This item belongs to another user",
        visibility: "privateAccess",
      },
    ])
    .returning();

  // Seed tags
  const seededTags = await db
    .insert(tags)
    .values([
      {
        id: "test-tag-1",
        userId: TEST_USER_ID,
        title: "Test Tag",
        color: "#FF5733",
      },
    ])
    .returning();

  // Link tag to test-public-item
  await db.insert(itemTags).values([
    {
      itemId: "test-public-item",
      tagId: "test-tag-1",
    },
  ]);

  console.log("========================================");
  console.log("Database seeded successfully!");
  console.log("========================================");
  console.log("Seeded items:");
  seededItems.forEach((item) => {
    console.log(`  - ID ${item.id}: "${item.title}" (${item.visibility})`);
  });
  console.log("Seeded entities:");
  seededCategories.forEach((c) => console.log(`  - Category: ${c.id} "${c.name}"`));
  seededLocations.forEach((l) => console.log(`  - Location: ${l.id} "${l.title}"`));
  seededAuthors.forEach((a) => console.log(`  - Author: ${a.id} "${a.name}"`));
  seededTags.forEach((t) => console.log(`  - Tag: ${t.id} "${t.title}" (${t.color})`));
  console.log("========================================");
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Seed failed:", error);
    process.exit(1);
  });
