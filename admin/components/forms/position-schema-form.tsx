"use client";

import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
import { JsonSchemaEditor, type JsonSchema } from "@/lib/json-schema-editor";

const positionSchemaSchema = z.object({
  name: z.string().min(1, "Name is required"),
  schema: z.custom<JsonSchema | null>((val) => val !== null, "Schema is required"),
});

type PositionSchemaFormData = z.infer<typeof positionSchemaSchema>;

interface PositionSchemaFormProps {
  positionSchema?: PositionSchema;
}

const defaultSchema: JsonSchema = {
  type: "object",
  properties: {
    bookshelf: {
      type: "integer",
      title: "Bookshelf Number",
    },
    row: {
      type: "integer",
      title: "Row",
    },
    column: {
      type: "integer",
      title: "Column",
    },
  },
  required: ["bookshelf", "row"],
};

export function PositionSchemaForm({ positionSchema }: PositionSchemaFormProps) {
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const isEditing = !!positionSchema;

  const {
    register,
    handleSubmit,
    control,
    formState: { errors },
  } = useForm<PositionSchemaFormData>({
    resolver: zodResolver(positionSchemaSchema),
    defaultValues: {
      name: positionSchema?.name || "",
      schema: positionSchema?.schema
        ? (positionSchema.schema as JsonSchema)
        : defaultSchema,
    },
  });

  const onSubmit = async (data: PositionSchemaFormData) => {
    if (!data.schema) {
      toast.error("Schema is required");
      return;
    }

    setIsSubmitting(true);
    try {
      const result = isEditing
        ? await updatePositionSchemaAction(positionSchema.id, {
            name: data.name,
            schema: data.schema,
          })
        : await createPositionSchemaAction({
            name: data.name,
            schema: data.schema,
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
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6" data-testid="position-schema-form">
          <div className="space-y-2">
            <Label htmlFor="name">Schema Name *</Label>
            <Input
              id="name"
              {...register("name")}
              placeholder="e.g., Bookshelf Position, Drawer Location"
              data-testid="position-schema-name-input"
            />
            {errors.name && (
              <p className="text-sm text-destructive">{errors.name.message}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label>JSON Schema *</Label>
            <Controller
              name="schema"
              control={control}
              render={({ field }) => (
                <JsonSchemaEditor
                  value={field.value}
                  onChange={field.onChange}
                  disabled={isSubmitting}
                  placeholder="Define fields like bookshelf, row, column, drawer, etc."
                />
              )}
            />
            {errors.schema && (
              <p className="text-sm text-destructive">{errors.schema.message}</p>
            )}
            <p className="text-sm text-muted-foreground">
              Use the visual editor to define fields or switch to Raw JSON for advanced editing.
            </p>
          </div>

          <div className="flex gap-4">
            <Button type="submit" disabled={isSubmitting} data-testid="position-schema-submit-button">
              {isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              {isEditing ? "Update Schema" : "Create Schema"}
            </Button>
            <Button
              type="button"
              variant="outline"
              onClick={() => router.push("/position-schemas")}
              data-testid="position-schema-cancel-button"
            >
              Cancel
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
