"use client";

import { useState } from "react";
import Form from "@rjsf/shadcn";
import validator from "@rjsf/validator-ajv8";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Label } from "@/components/ui/label";
import { Loader2, Plus, Trash } from "lucide-react";
import { toast } from "sonner";
import {
  createPositionAction,
  updatePositionAction,
  deletePositionAction,
  type PositionWithSchema,
} from "@/lib/actions/position-actions";
import type { PositionSchema } from "@/lib/db";

interface PositionFormProps {
  itemId: number;
  positions: PositionWithSchema[];
  positionSchemas: PositionSchema[];
  onUpdate?: () => void;
}

export function PositionForm({
  itemId,
  positions,
  positionSchemas,
  onUpdate,
}: PositionFormProps) {
  const [loading, setLoading] = useState(false);
  const [selectedSchemaId, setSelectedSchemaId] = useState<number | null>(null);

  const handleAddPosition = async () => {
    if (!selectedSchemaId) {
      toast.error("Please select a position schema");
      return;
    }

    setLoading(true);
    try {
      const result = await createPositionAction({
        itemId,
        positionSchemaId: selectedSchemaId,
        data: {},
      });

      if (result.success) {
        toast.success("Position added");
        setSelectedSchemaId(null);
        onUpdate?.();
      } else {
        toast.error(result.error || "Failed to add position");
      }
    } catch {
      toast.error("Failed to add position");
    } finally {
      setLoading(false);
    }
  };

  const handleUpdatePosition = async (
    positionId: number,
    data: Record<string, unknown>,
  ) => {
    setLoading(true);
    try {
      const result = await updatePositionAction(positionId, { data });

      if (result.success) {
        toast.success("Position updated");
        onUpdate?.();
      } else {
        toast.error(result.error || "Failed to update position");
      }
    } catch {
      toast.error("Failed to update position");
    } finally {
      setLoading(false);
    }
  };

  const handleDeletePosition = async (positionId: number) => {
    setLoading(true);
    try {
      const result = await deletePositionAction(positionId);

      if (result.success) {
        toast.success("Position deleted");
        onUpdate?.();
      } else {
        toast.error(result.error || "Failed to delete position");
      }
    } catch {
      toast.error("Failed to delete position");
    } finally {
      setLoading(false);
    }
  };

  // Filter out schemas that are already used
  const usedSchemaIds = new Set(positions.map((p) => p.positionSchemaId));
  const availableSchemas = positionSchemas.filter(
    (s) => !usedSchemaIds.has(s.id),
  );

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg">Position Information</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        {positions.length === 0 && availableSchemas.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-4">
            No position schemas available. Create position schemas first.
          </p>
        ) : (
          <>
            {positions.map((position) => (
              <div key={position.id} className="border rounded-lg p-4">
                <div className="flex items-center justify-between mb-4">
                  <h4 className="font-medium">
                    {position.positionSchema?.name || "Unknown Schema"}
                  </h4>
                  <AlertDialog>
                    <AlertDialogTrigger asChild>
                      <Button
                        variant="ghost"
                        size="sm"
                        disabled={loading}
                      >
                        <Trash className="h-4 w-4 text-destructive" />
                      </Button>
                    </AlertDialogTrigger>
                    <AlertDialogContent>
                      <AlertDialogHeader>
                        <AlertDialogTitle>Delete position?</AlertDialogTitle>
                        <AlertDialogDescription>
                          This action cannot be undone. This will permanently delete the {position.positionSchema?.name || "position"} data.
                        </AlertDialogDescription>
                      </AlertDialogHeader>
                      <AlertDialogFooter>
                        <AlertDialogCancel>Cancel</AlertDialogCancel>
                        <AlertDialogAction
                          variant="destructive"
                          onClick={() => handleDeletePosition(position.id)}
                        >
                          Delete
                        </AlertDialogAction>
                      </AlertDialogFooter>
                    </AlertDialogContent>
                  </AlertDialog>
                </div>
                {position.positionSchema?.schema && (
                  <Form
                    schema={position.positionSchema.schema as object}
                    formData={position.data}
                    validator={validator}
                    onSubmit={({ formData }) =>
                      handleUpdatePosition(position.id, formData)
                    }
                    uiSchema={{
                      "ui:submitButtonOptions": {
                        norender: false,
                        submitText: "Save",
                        props: {
                          disabled: loading,
                        },
                      },
                    }}
                  />
                )}
              </div>
            ))}

            {availableSchemas.length > 0 && (
              <div className="flex items-end gap-2">
                <div className="flex-1 space-y-2">
                  <Label>Add Position</Label>
                  <Select
                    value={selectedSchemaId?.toString() ?? ""}
                    onValueChange={(v) =>
                      setSelectedSchemaId(v ? parseInt(v) : null)
                    }
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select schema" />
                    </SelectTrigger>
                    <SelectContent>
                      {availableSchemas.map((schema) => (
                        <SelectItem
                          key={schema.id}
                          value={schema.id.toString()}
                        >
                          {schema.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <Button
                  onClick={handleAddPosition}
                  disabled={loading || !selectedSchemaId}
                >
                  {loading ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <Plus className="h-4 w-4" />
                  )}
                </Button>
              </div>
            )}
          </>
        )}
      </CardContent>
    </Card>
  );
}
