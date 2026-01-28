"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import type { PositionSchema } from "@/lib/db";
import {
  createPositionSchemaAction,
  updatePositionSchemaAction,
} from "@/lib/actions/position-schema-actions";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Loader2 } from "lucide-react";

const positionSchemaSchema = z.object({
  name: z.string().min(1, "Name is required"),
  schema: z.string().min(1, "Schema is required"),
});

type PositionSchemaFormData = z.infer<typeof positionSchemaSchema>;

interface PositionSchemaFormProps {
  positionSchema?: PositionSchema;
}

const exampleSchema = `{
  "type": "object",
  "properties": {
    "bookshelf": {
      "type": "integer",
      "title": "Bookshelf Number"
    },
    "row": {
      "type": "integer",
      "title": "Row"
    },
    "column": {
      "type": "integer",
      "title": "Column"
    }
  },
  "required": ["bookshelf", "row"]
}`;

export function PositionSchemaForm({ positionSchema }: PositionSchemaFormProps) {
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [schemaError, setSchemaError] = useState<string | null>(null);
  const isEditing = !!positionSchema;

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<PositionSchemaFormData>({
    resolver: zodResolver(positionSchemaSchema),
    defaultValues: {
      name: positionSchema?.name || "",
      schema: positionSchema?.schema
        ? JSON.stringify(positionSchema.schema, null, 2)
        : exampleSchema,
    },
  });

  const onSubmit = async (data: PositionSchemaFormData) => {
    setSchemaError(null);

    // Validate JSON Schema
    let parsedSchema;
    try {
      parsedSchema = JSON.parse(data.schema);
    } catch {
      setSchemaError("Invalid JSON. Please check your schema syntax.");
      return;
    }

    // Basic JSON Schema validation
    if (typeof parsedSchema !== "object" || !parsedSchema.type) {
      setSchemaError("Invalid JSON Schema. Must have a 'type' property.");
      return;
    }

    setIsSubmitting(true);
    try {
      const result = isEditing
        ? await updatePositionSchemaAction(positionSchema.id, {
            name: data.name,
            schema: parsedSchema,
          })
        : await createPositionSchemaAction({
            name: data.name,
            schema: parsedSchema,
          });

      if (result.success) {
        toast.success(isEditing ? "Position schema updated" : "Position schema created");
        router.push("/position-schemas");
      } else {
        toast.error(result.error || "Failed to save position schema");
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          {isEditing ? "Edit Position Schema" : "Create Position Schema"}
        </CardTitle>
        <CardDescription>
          Define a JSON Schema to describe how items are positioned in storage.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          <div className="space-y-2">
            <Label htmlFor="name">Schema Name *</Label>
            <Input
              id="name"
              {...register("name")}
              placeholder="e.g., Bookshelf Position, Drawer Location"
            />
            {errors.name && (
              <p className="text-sm text-destructive">{errors.name.message}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="schema">JSON Schema *</Label>
            <Textarea
              id="schema"
              {...register("schema")}
              placeholder="Enter JSON Schema"
              rows={15}
              className="font-mono text-sm"
            />
            {errors.schema && (
              <p className="text-sm text-destructive">{errors.schema.message}</p>
            )}
            {schemaError && (
              <p className="text-sm text-destructive">{schemaError}</p>
            )}
            <p className="text-sm text-muted-foreground">
              Use JSON Schema format to define fields like bookshelf, row, column, drawer, etc.
            </p>
          </div>

          <div className="flex gap-4">
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              {isEditing ? "Update Schema" : "Create Schema"}
            </Button>
            <Button
              type="button"
              variant="outline"
              onClick={() => router.back()}
            >
              Cancel
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
