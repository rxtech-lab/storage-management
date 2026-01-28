import { notFound } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { ArrowLeft } from "lucide-react";
import { PositionSchemaForm } from "@/components/forms/position-schema-form";
import { PositionSchemaDeleteButton } from "@/components/forms/position-schema-delete-button";
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
    <div className="max-w-4xl">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-4">
          <Link href="/position-schemas">
            <Button variant="ghost" size="icon">
              <ArrowLeft className="h-4 w-4" />
            </Button>
          </Link>
          <div>
            <h1 className="text-3xl font-bold">{positionSchema.name}</h1>
            <p className="text-muted-foreground">
              Update position schema details
            </p>
          </div>
        </div>
        <PositionSchemaDeleteButton
          schemaId={positionSchema.id}
          schemaName={positionSchema.name}
        />
      </div>
      <PositionSchemaForm positionSchema={positionSchema} />
    </div>
  );
}
