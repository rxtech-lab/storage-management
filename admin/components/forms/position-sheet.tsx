"use client";

import { useState } from "react";
import Form from "@rjsf/shadcn";
import validator from "@rjsf/validator-ajv8";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Plus, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { PositionSchemaSheet } from "./position-schema-sheet";
import {
  createPositionAction,
  type PositionWithSchema,
} from "@/lib/actions/position-actions";
import type { PositionSchema } from "@/lib/db";

export interface PendingPosition {
  tempId: string;
  positionSchemaId: number;
  schema: PositionSchema;
  data: Record<string, unknown>;
}

interface PositionSheetProps {
  itemId?: number;
  positionSchemas: PositionSchema[];
  onPositionCreated?: (position: PositionWithSchema) => void;
  onPendingPosition?: (pending: PendingPosition) => void;
  onSchemaCreated?: (schema: PositionSchema) => void;
  trigger?: React.ReactNode;
}

export function PositionSheet({
  itemId,
  positionSchemas,
  onPositionCreated,
  onPendingPosition,
  onSchemaCreated,
  trigger,
}: PositionSheetProps) {
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [selectedSchemaId, setSelectedSchemaId] = useState<number | null>(null);
  const [schemas, setSchemas] = useState(positionSchemas);

  const selectedSchema = schemas.find((s) => s.id === selectedSchemaId);

  const handleSchemaCreated = (schema: PositionSchema) => {
    setSchemas([...schemas, schema]);
    setSelectedSchemaId(schema.id);
    onSchemaCreated?.(schema);
  };

  const handleFormSubmit = async (formData: Record<string, unknown>) => {
    if (!selectedSchemaId || !selectedSchema) {
      toast.error("Please select a schema");
      return;
    }

    if (itemId) {
      // Edit mode: create position immediately
      setLoading(true);
      try {
        const result = await createPositionAction({
          itemId,
          positionSchemaId: selectedSchemaId,
          data: formData,
        });

        if (result.success && result.data) {
          toast.success("Position created");
          onPositionCreated?.({
            ...result.data,
            positionSchema: selectedSchema,
          });
          setOpen(false);
          setSelectedSchemaId(null);
        } else {
          toast.error(result.error || "Failed to create position");
        }
      } catch {
        toast.error("Failed to create position");
      } finally {
        setLoading(false);
      }
    } else {
      // Create mode: store locally
      const pending: PendingPosition = {
        tempId: crypto.randomUUID(),
        positionSchemaId: selectedSchemaId,
        schema: selectedSchema,
        data: formData,
      };
      onPendingPosition?.(pending);
      toast.success("Position added");
      setOpen(false);
      setSelectedSchemaId(null);
    }
  };

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        {trigger || (
          <Button variant="outline" size="sm" type="button">
            <Plus className="h-4 w-4 mr-2" />
            Add Position
          </Button>
        )}
      </SheetTrigger>
      <SheetContent className="sm:max-w-lg max-w-3xl overflow-y-auto">
        <SheetHeader>
          <SheetTitle>Add Position</SheetTitle>
          <SheetDescription>
            Select a schema and fill in the position data.
          </SheetDescription>
        </SheetHeader>
        <div className="space-y-4 px-2 pb-6">
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <Label>Position Schema</Label>
              <PositionSchemaSheet onCreated={handleSchemaCreated} />
            </div>
            <Select
              value={selectedSchemaId?.toString() ?? ""}
              onValueChange={(v) =>
                setSelectedSchemaId(v ? parseInt(v) : null)
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="Select a schema" />
              </SelectTrigger>
              <SelectContent>
                {schemas.map((schema) => (
                  <SelectItem key={schema.id} value={schema.id.toString()}>
                    {schema.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {schemas.length === 0 && (
              <p className="text-sm text-muted-foreground">
                No schemas available. Create one first.
              </p>
            )}
          </div>

          {selectedSchema && (
            <div className="space-y-2">
              <Label>Position Data</Label>
              <Form
                schema={selectedSchema.schema as object}
                validator={validator}
                onSubmit={({ formData }) => handleFormSubmit(formData)}
                disabled={loading}
              >
                <Button type="submit" className="mt-4" disabled={loading}>
                  {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
                  {itemId ? "Create Position" : "Add Position"}
                </Button>
              </Form>
            </div>
          )}
        </div>
      </SheetContent>
    </Sheet>
  );
}
