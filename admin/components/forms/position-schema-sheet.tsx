"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
  SheetFooter,
} from "@/components/ui/sheet";
import { Plus, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { createPositionSchemaAction } from "@/lib/actions/position-schema-actions";
import type { PositionSchema } from "@/lib/db";

const EXAMPLE_SCHEMA = `{
  "type": "object",
  "properties": {
    "shelf": {
      "type": "string",
      "title": "Shelf"
    },
    "row": {
      "type": "number",
      "title": "Row"
    },
    "column": {
      "type": "number",
      "title": "Column"
    }
  },
  "required": ["shelf"]
}`;

interface PositionSchemaSheetProps {
  onCreated?: (schema: PositionSchema) => void;
  trigger?: React.ReactNode;
}

export function PositionSchemaSheet({
  onCreated,
  trigger,
}: PositionSchemaSheetProps) {
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [name, setName] = useState("");
  const [schema, setSchema] = useState("");
  const [schemaError, setSchemaError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSchemaError(null);

    if (!name.trim()) {
      toast.error("Name is required");
      return;
    }

    if (!schema.trim()) {
      toast.error("Schema is required");
      return;
    }

    let parsedSchema: object;
    try {
      parsedSchema = JSON.parse(schema);
    } catch {
      setSchemaError("Invalid JSON. Please check your schema syntax.");
      return;
    }

    if (
      typeof parsedSchema !== "object" ||
      !("type" in parsedSchema) ||
      parsedSchema.type !== "object"
    ) {
      setSchemaError(
        'Invalid JSON Schema. Root must be an object with "type": "object".'
      );
      return;
    }

    setLoading(true);

    try {
      const result = await createPositionSchemaAction({
        name: name.trim(),
        schema: parsedSchema,
      });

      if (result.success && result.data) {
        toast.success("Position schema created");
        onCreated?.(result.data);
        setOpen(false);
        setName("");
        setSchema("");
        setSchemaError(null);
      } else {
        toast.error(result.error || "Failed to create position schema");
      }
    } catch {
      toast.error("Failed to create position schema");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        {trigger || (
          <Button variant="outline" size="sm" type="button">
            <Plus className="h-4 w-4" />
          </Button>
        )}
      </SheetTrigger>
      <SheetContent className="sm:max-w-lg max-w-3xl overflow-y-auto">
        <SheetHeader>
          <SheetTitle>New Position Schema</SheetTitle>
          <SheetDescription>
            Create a JSON Schema that defines the structure of position data.
          </SheetDescription>
        </SheetHeader>
        <form onSubmit={handleSubmit} className="space-y-4 px-2 pb-6">
          <div className="space-y-2">
            <Label htmlFor="schema-name">Name</Label>
            <Input
              id="schema-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g., Warehouse Location"
              required
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="schema-json">JSON Schema</Label>
            <Textarea
              id="schema-json"
              value={schema}
              onChange={(e) => {
                setSchema(e.target.value);
                setSchemaError(null);
              }}
              placeholder={EXAMPLE_SCHEMA}
              rows={12}
              className="font-mono text-sm"
            />
            {schemaError && (
              <p className="text-sm text-destructive">{schemaError}</p>
            )}
            <p className="text-xs text-muted-foreground">
              Define the fields for this position type using JSON Schema format.
            </p>
          </div>

          <SheetFooter>
            <Button type="submit" disabled={loading}>
              {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
              Create Schema
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  );
}
