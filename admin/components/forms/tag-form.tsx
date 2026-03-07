"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import type { Tag } from "@/lib/db";
import {
  createTagAction,
  updateTagAction,
  deleteTagAction,
} from "@/lib/actions/tag-actions";
import { DeleteConfirmButton } from "@/components/ui/delete-confirm-button";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Loader2 } from "lucide-react";

const tagSchema = z.object({
  title: z.string().min(1, "Title is required"),
  color: z.string().min(1, "Color is required").regex(/^#[0-9A-Fa-f]{6}$/, "Must be a valid hex color"),
});

type TagFormData = z.infer<typeof tagSchema>;

interface TagFormProps {
  tag?: Tag;
}

export function TagForm({ tag }: TagFormProps) {
  const router = useRouter();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const isEditing = !!tag;

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors },
  } = useForm<TagFormData>({
    resolver: zodResolver(tagSchema),
    defaultValues: {
      title: tag?.title || "",
      color: tag?.color || "#3B82F6",
    },
  });

  const currentColor = watch("color");

  const onSubmit = async (data: TagFormData) => {
    setIsSubmitting(true);
    try {
      const result = isEditing
        ? await updateTagAction(tag.id, data)
        : await createTagAction(data);

      if (result.success) {
        toast.success(isEditing ? "Tag updated" : "Tag created");
        router.push("/tags");
      } else {
        toast.error(result.error || "Failed to save tag");
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>{isEditing ? "Edit Tag" : "Create Tag"}</CardTitle>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
          <div className="space-y-2">
            <Label htmlFor="title">Tag Title *</Label>
            <Input id="title" {...register("title")} placeholder="Tag title" />
            {errors.title && (
              <p className="text-sm text-destructive">{errors.title.message}</p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="color">Color *</Label>
            <div className="flex items-center gap-3">
              <input
                type="color"
                id="color"
                {...register("color")}
                className="h-10 w-14 cursor-pointer rounded border p-1"
              />
              <Input
                {...register("color")}
                placeholder="#3B82F6"
                className="max-w-32 font-mono"
              />
              <div
                className="flex items-center gap-2 rounded-full px-3 py-1 text-sm font-medium"
                style={{
                  backgroundColor: currentColor,
                  color: isLightColor(currentColor) ? "#000" : "#fff",
                }}
              >
                Preview
              </div>
            </div>
            {errors.color && (
              <p className="text-sm text-destructive">{errors.color.message}</p>
            )}
          </div>

          <div className="flex gap-4">
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              {isEditing ? "Update Tag" : "Create Tag"}
            </Button>
            <Button
              type="button"
              variant="outline"
              onClick={() => router.back()}
            >
              Cancel
            </Button>
            {isEditing && (
              <DeleteConfirmButton
                onConfirm={async () => {
                  const result = await deleteTagAction(tag.id);
                  if (result.success) {
                    toast.success("Tag deleted");
                    router.push("/tags");
                  } else {
                    toast.error(result.error || "Failed to delete tag");
                  }
                }}
                title={`Delete "${tag.title}"?`}
                description="This action cannot be undone. This will permanently delete this tag and remove it from all items."
              />
            )}
          </div>
        </form>
      </CardContent>
    </Card>
  );
}

function isLightColor(hex: string): boolean {
  const color = hex.replace("#", "");
  if (color.length !== 6) return true;
  const r = parseInt(color.substring(0, 2), 16) / 255;
  const g = parseInt(color.substring(2, 4), 16) / 255;
  const b = parseInt(color.substring(4, 6), 16) / 255;
  const luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  return luminance > 0.5;
}
