import { db } from "../lib/db";
import { items } from "../lib/db/schema/items";

async function seed() {
  console.log("Seeding test data...");

  const seededItems = await db
    .insert(items)
    .values([
      {
        id: 1,
        userId: "test-user-id", // default test user
        title: "Public Test Item",
        description: "This is a public test item for E2E testing",
        visibility: "publicAccess",
      },
      {
        id: 2,
        userId: "b8da73c7-eb56-46a2-a20a-385d298dfa97", // different user for access control testing
        title: "Private Test Item",
        description: "This is a private test item for E2E testing",
        visibility: "privateAccess",
      },
      {
        id: 3,
        userId: "different-id", // different user for access control testing
        title: "Another User's Item",
        description: "This item belongs to another user",
        visibility: "privateAccess",
      },
    ])
    .returning();

  console.log("========================================");
  console.log("Database seeded successfully!");
  console.log("========================================");
  console.log("Seeded items:");
  seededItems.forEach((item) => {
    console.log(`  - ID ${item.id}: "${item.title}" (${item.visibility})`);
  });
  console.log("========================================");
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Seed failed:", error);
    process.exit(1);
  });
