import { notFound } from "next/navigation";
import { PositionSchemaForm } from "@/components/forms/position-schema-form";
import { getPositionSchema } from "@/lib/actions/position-schema-actions";

interface EditPositionSchemaPageProps {
  params: Promise<{ id: string }>;
}

export default async function EditPositionSchemaPage({ params }: EditPositionSchemaPageProps) {
  const { id } = await params;
  const positionSchema = await getPositionSchema(parseInt(id));

  if (!positionSchema) {
    notFound();
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">Edit Position Schema</h1>
        <p className="text-muted-foreground">
          Update position schema details
        </p>
      </div>
      <PositionSchemaForm positionSchema={positionSchema} />
    </div>
  );
}
