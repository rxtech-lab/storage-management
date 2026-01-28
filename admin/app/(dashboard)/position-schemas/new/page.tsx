import { PositionSchemaForm } from "@/components/forms/position-schema-form";

export default function NewPositionSchemaPage() {
  return (
    <div className="max-w-4xl mx-auto">
      <div className="mb-6">
        <h1 className="text-3xl font-bold">New Position Schema</h1>
        <p className="text-muted-foreground">
          Create a new schema for item positioning
        </p>
      </div>
      <PositionSchemaForm />
    </div>
  );
}
