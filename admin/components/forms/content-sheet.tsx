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
import { Plus, Loader2, File, Image, Video } from "lucide-react";
import { toast } from "sonner";
import { createContentAction } from "@/lib/actions/content-actions";
import {
  contentSchemas,
  type ContentType,
} from "@/lib/schemas/content-schemas";
import type { Content, ContentData } from "@/lib/db";

export interface PendingContent {
  tempId: string;
  type: ContentType;
  data: ContentData;
}

const contentIcons: Record<ContentType, typeof File> = {
  file: File,
  image: Image,
  video: Video,
};

interface ContentSheetProps {
  itemId?: number;
  onContentCreated?: (content: Content) => void;
  onPendingContent?: (pending: PendingContent) => void;
  trigger?: React.ReactNode;
}

export function ContentSheet({
  itemId,
  onContentCreated,
  onPendingContent,
  trigger,
}: ContentSheetProps) {
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [selectedType, setSelectedType] = useState<ContentType | null>(null);

  const handleFormSubmit = async (formData: ContentData) => {
    if (!selectedType) {
      toast.error("Please select a content type");
      return;
    }

    if (itemId) {
      setLoading(true);
      try {
        const result = await createContentAction({
          itemId,
          type: selectedType,
          data: formData,
        });

        if (result.success && result.data) {
          toast.success("Content created");
          onContentCreated?.(result.data);
          setOpen(false);
          setSelectedType(null);
        } else {
          toast.error(result.error || "Failed to create content");
        }
      } catch {
        toast.error("Failed to create content");
      } finally {
        setLoading(false);
      }
    } else {
      const pending: PendingContent = {
        tempId: crypto.randomUUID(),
        type: selectedType,
        data: formData,
      };
      onPendingContent?.(pending);
      toast.success("Content added");
      setOpen(false);
      setSelectedType(null);
    }
  };

  const handleOpenChange = (isOpen: boolean) => {
    setOpen(isOpen);
    if (!isOpen) {
      setSelectedType(null);
    }
  };

  return (
    <Sheet open={open} onOpenChange={handleOpenChange}>
      <SheetTrigger asChild>
        {trigger || (
          <Button variant="ghost" size="sm" type="button" className="gap-1">
            <Plus className="h-4 w-4" />
            Add
          </Button>
        )}
      </SheetTrigger>
      <SheetContent className="sm:max-w-lg max-w-3xl overflow-y-auto">
        <SheetHeader>
          <SheetTitle>Add Content</SheetTitle>
          <SheetDescription>
            Select a content type and fill in the details.
          </SheetDescription>
        </SheetHeader>
        <div className="space-y-4 px-2 pb-6">
          <div className="space-y-2">
            <Label>Content Type</Label>
            <Select
              value={selectedType ?? ""}
              onValueChange={(v) => setSelectedType(v as ContentType)}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select a type" />
              </SelectTrigger>
              <SelectContent>
                {(["file", "image", "video"] as ContentType[]).map((type) => {
                  const Icon = contentIcons[type];
                  return (
                    <SelectItem key={type} value={type}>
                      <div className="flex items-center gap-2">
                        <Icon className="h-4 w-4" />
                        <span className="capitalize">{type}</span>
                      </div>
                    </SelectItem>
                  );
                })}
              </SelectContent>
            </Select>
          </div>

          {selectedType && (
            <div className="space-y-2">
              <Label>Content Data</Label>
              <Form
                schema={contentSchemas[selectedType]}
                validator={validator}
                onSubmit={({ formData }) => handleFormSubmit(formData)}
                disabled={loading}
              >
                <Button type="submit" className="mt-4" disabled={loading}>
                  {loading && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
                  {itemId ? "Create Content" : "Add Content"}
                </Button>
              </Form>
            </div>
          )}
        </div>
      </SheetContent>
    </Sheet>
  );
}
