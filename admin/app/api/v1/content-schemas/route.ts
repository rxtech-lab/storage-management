import { NextResponse } from "next/server";
import { contentSchemas, type ContentType } from "@/lib/schemas/content-schemas";

/**
 * List content schemas
 * @operationId getContentSchemas
 * @description Returns predefined JSON schemas for content types (file, image, video). Used by iOS app to render dynamic forms.
 * @response ContentSchemasResponseSchema
 * @tag ContentSchemas
 * @responseSet public
 * @openapi
 */
export async function GET() {
  const schemas = (Object.keys(contentSchemas) as ContentType[]).map((type) => ({
    type,
    name: type.charAt(0).toUpperCase() + type.slice(1),
    schema: contentSchemas[type],
  }));

  return NextResponse.json(schemas);
}
