"use client";

import { useState } from "react";
import Form from "@rjsf/core";
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
import { Label } from "@/components/ui/label";
import { Loader2, Plus, Trash, File, Image, Video } from "lucide-react";
import { toast } from "sonner";
import {
  createContentAction,
  updateContentAction,
  deleteContentAction,
} from "@/lib/actions/content-actions";
import type { Content, ContentData } from "@/lib/db";

import type { JSONSchema7 } from "json-schema";

// JSON Schemas for content types
const fileSchema: JSONSchema7 = {
  type: "object",
  required: ["title", "mime_type", "size", "file_path"],
  properties: {
    title: { type: "string", title: "Title" },
    description: { type: "string", title: "Description" },
    mime_type: { type: "string", title: "MIME Type" },
    size: { type: "number", title: "Size (bytes)" },
    file_path: { type: "string", title: "File Path" },
  },
};

const imageSchema: JSONSchema7 = {
  type: "object",
  required: ["title", "mime_type", "size", "file_path"],
  properties: {
    title: { type: "string", title: "Title" },
    description: { type: "string", title: "Description" },
    mime_type: { type: "string", title: "MIME Type" },
    size: { type: "number", title: "Size (bytes)" },
    file_path: { type: "string", title: "File Path" },
    preview_image_url: { type: "string", title: "Preview Image URL" },
  },
};

const videoSchema: JSONSchema7 = {
  type: "object",
  required: ["title", "mime_type", "size", "file_path", "video_length"],
  properties: {
    title: { type: "string", title: "Title" },
    description: { type: "string", title: "Description" },
    mime_type: { type: "string", title: "MIME Type" },
    size: { type: "number", title: "Size (bytes)" },
    file_path: { type: "string", title: "File Path" },
    preview_image_url: { type: "string", title: "Preview Image URL" },
    video_length: { type: "number", title: "Video Length (seconds)" },
    preview_video_url: { type: "string", title: "Preview Video URL" },
  },
};

const schemas: Record<"file" | "image" | "video", JSONSchema7> = {
  file: fileSchema,
  image: imageSchema,
  video: videoSchema,
};

const icons = {
  file: File,
  image: Image,
  video: Video,
};

interface ContentFormProps {
  itemId: number;
  contents: Content[];
  onUpdate?: () => void;
}

export function ContentForm({ itemId, contents, onUpdate }: ContentFormProps) {
  const [loading, setLoading] = useState(false);
  const [selectedType, setSelectedType] = useState<"file" | "image" | "video" | null>(null);

  const handleAddContent = async () => {
    if (!selectedType) {
      toast.error("Please select a content type");
      return;
    }

    setLoading(true);
    try {
      const result = await createContentAction({
        itemId,
        type: selectedType,
        data: { title: "", mime_type: "", size: 0, file_path: "" } as ContentData,
      });

      if (result.success) {
        toast.success("Content added");
        setSelectedType(null);
        onUpdate?.();
      } else {
        toast.error(result.error || "Failed to add content");
      }
    } catch {
      toast.error("Failed to add content");
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateContent = async (
    contentId: number,
    type: "file" | "image" | "video",
    data: ContentData
  ) => {
    setLoading(true);
    try {
      const result = await updateContentAction(contentId, { type, data });

      if (result.success) {
        toast.success("Content updated");
        onUpdate?.();
      } else {
        toast.error(result.error || "Failed to update content");
      }
    } catch {
      toast.error("Failed to update content");
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteContent = async (contentId: number) => {
    if (!confirm("Are you sure you want to delete this content?")) return;

    setLoading(true);
    try {
      const result = await deleteContentAction(contentId);

      if (result.success) {
        toast.success("Content deleted");
        onUpdate?.();
      } else {
        toast.error(result.error || "Failed to delete content");
      }
    } catch {
      toast.error("Failed to delete content");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-lg">Contents</CardTitle>
      </CardHeader>
      <CardContent className="space-y-6">
        {contents.length === 0 ? (
          <p className="text-sm text-muted-foreground text-center py-4">
            No contents yet. Add files, images, or videos.
          </p>
        ) : (
          contents.map((content) => {
            const Icon = icons[content.type];
            return (
              <div key={content.id} className="border rounded-lg p-4">
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-2">
                    <Icon className="h-5 w-5 text-muted-foreground" />
                    <h4 className="font-medium capitalize">{content.type}</h4>
                  </div>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => handleDeleteContent(content.id)}
                    disabled={loading}
                  >
                    <Trash className="h-4 w-4 text-destructive" />
                  </Button>
                </div>
                <Form
                  schema={schemas[content.type]}
                  formData={content.data}
                  validator={validator}
                  onSubmit={({ formData }) =>
                    handleUpdateContent(content.id, content.type, formData)
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
              </div>
            );
          })
        )}

        <div className="flex items-end gap-2">
          <div className="flex-1 space-y-2">
            <Label>Add Content</Label>
            <Select
              value={selectedType ?? ""}
              onValueChange={(v) =>
                setSelectedType(v as "file" | "image" | "video" | null)
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="Select type" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="file">
                  <div className="flex items-center gap-2">
                    <File className="h-4 w-4" />
                    File
                  </div>
                </SelectItem>
                <SelectItem value="image">
                  <div className="flex items-center gap-2">
                    <Image className="h-4 w-4" />
                    Image
                  </div>
                </SelectItem>
                <SelectItem value="video">
                  <div className="flex items-center gap-2">
                    <Video className="h-4 w-4" />
                    Video
                  </div>
                </SelectItem>
              </SelectContent>
            </Select>
          </div>
          <Button
            onClick={handleAddContent}
            disabled={loading || !selectedType}
          >
            {loading ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Plus className="h-4 w-4" />
            )}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
