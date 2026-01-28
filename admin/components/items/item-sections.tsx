"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  ChevronRight,
  Plus,
  Trash,
  MapPin,
  ExternalLink,
  Eye,
  EyeOff,
  File,
  Image,
  Video,
  Mail,
  Loader2,
  Upload,
  Box,
} from "lucide-react";
import { toast } from "sonner";
import Form from "@rjsf/core";
import validator from "@rjsf/validator-ajv8";
import { PositionSheet } from "@/components/forms/position-sheet";
import {
  deletePositionAction,
  type PositionWithSchema,
} from "@/lib/actions/position-actions";
import {
  createContentAction,
  updateContentAction,
  deleteContentAction,
} from "@/lib/actions/content-actions";
import {
  addToWhitelistAction,
  removeFromWhitelistAction,
  bulkAddToWhitelistAction,
} from "@/lib/actions/whitelist-actions";
import type { Content, ContentData, ItemWhitelist, PositionSchema } from "@/lib/db";
import type { ItemWithRelations } from "@/lib/actions/item-actions";
import type { JSONSchema7 } from "json-schema";

// Content schemas
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

const contentSchemas: Record<"file" | "image" | "video", JSONSchema7> = {
  file: fileSchema,
  image: imageSchema,
  video: videoSchema,
};

const contentIcons = {
  file: File,
  image: Image,
  video: Video,
};

interface ItemSectionsProps {
  item: ItemWithRelations;
  positions: PositionWithSchema[];
  positionSchemas: PositionSchema[];
  contents: Content[];
  children: ItemWithRelations[];
  whitelist: ItemWhitelist[];
  onUpdate?: () => void;
}

export function ItemSections({
  item,
  positions: initialPositions,
  positionSchemas: initialSchemas,
  contents: initialContents,
  children,
  whitelist: initialWhitelist,
  onUpdate,
}: ItemSectionsProps) {
  const [isPending, startTransition] = useTransition();
  const [positions, setPositions] = useState(initialPositions);
  const [positionSchemas, setPositionSchemas] = useState(initialSchemas);
  const [contents, setContents] = useState(initialContents);
  const [whitelist, setWhitelist] = useState(initialWhitelist);

  // Content state
  const [selectedContentType, setSelectedContentType] = useState<
    "file" | "image" | "video" | null
  >(null);
  const [contentLoading, setContentLoading] = useState(false);

  // Whitelist state
  const [email, setEmail] = useState("");
  const [bulkEmails, setBulkEmails] = useState("");
  const [showBulk, setShowBulk] = useState(false);
  const [whitelistLoading, setWhitelistLoading] = useState(false);

  // Position handlers
  const handleDeletePosition = async (positionId: number) => {
    startTransition(async () => {
      try {
        const result = await deletePositionAction(positionId);
        if (result.success) {
          setPositions(positions.filter((p) => p.id !== positionId));
          toast.success("Position deleted");
        } else {
          toast.error(result.error || "Failed to delete position");
        }
      } catch {
        toast.error("Failed to delete position");
      }
    });
  };

  // Content handlers
  const handleAddContent = async () => {
    if (!selectedContentType) return;
    setContentLoading(true);
    try {
      const result = await createContentAction({
        itemId: item.id,
        type: selectedContentType,
        data: { title: "", mime_type: "", size: 0, file_path: "" } as ContentData,
      });
      if (result.success && result.data) {
        setContents([...contents, result.data]);
        toast.success("Content added");
        setSelectedContentType(null);
      } else {
        toast.error(result.error || "Failed to add content");
      }
    } catch {
      toast.error("Failed to add content");
    } finally {
      setContentLoading(false);
    }
  };

  const handleUpdateContent = async (
    contentId: number,
    type: "file" | "image" | "video",
    data: ContentData
  ) => {
    setContentLoading(true);
    try {
      const result = await updateContentAction(contentId, { type, data });
      if (result.success) {
        setContents(
          contents.map((c) => (c.id === contentId ? { ...c, type, data } : c))
        );
        toast.success("Content updated");
      } else {
        toast.error(result.error || "Failed to update content");
      }
    } catch {
      toast.error("Failed to update content");
    } finally {
      setContentLoading(false);
    }
  };

  const handleDeleteContent = async (contentId: number) => {
    if (!confirm("Are you sure you want to delete this content?")) return;
    setContentLoading(true);
    try {
      const result = await deleteContentAction(contentId);
      if (result.success) {
        setContents(contents.filter((c) => c.id !== contentId));
        toast.success("Content deleted");
      } else {
        toast.error(result.error || "Failed to delete content");
      }
    } catch {
      toast.error("Failed to delete content");
    } finally {
      setContentLoading(false);
    }
  };

  // Whitelist handlers
  const handleAddEmail = async () => {
    if (!email.trim()) return;
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email.trim())) {
      toast.error("Please enter a valid email");
      return;
    }
    setWhitelistLoading(true);
    try {
      const result = await addToWhitelistAction({
        itemId: item.id,
        email: email.trim(),
      });
      if (result.success && result.data) {
        setWhitelist([...whitelist, result.data]);
        toast.success("Email added to whitelist");
        setEmail("");
      } else {
        toast.error(result.error || "Failed to add email");
      }
    } catch {
      toast.error("Failed to add email");
    } finally {
      setWhitelistLoading(false);
    }
  };

  const handleBulkAdd = async () => {
    if (!bulkEmails.trim()) return;
    const emails = bulkEmails
      .split(/[\n,;]+/)
      .map((e) => e.trim())
      .filter(Boolean);
    if (emails.length === 0) return;
    setWhitelistLoading(true);
    try {
      const result = await bulkAddToWhitelistAction(item.id, emails);
      if (result.success) {
        toast.success(`Added ${result.added} email(s) to whitelist`);
        setBulkEmails("");
        setShowBulk(false);
        onUpdate?.();
      } else {
        toast.error(result.error || "Failed to add emails");
      }
    } catch {
      toast.error("Failed to add emails");
    } finally {
      setWhitelistLoading(false);
    }
  };

  const handleRemoveEmail = async (id: number) => {
    setWhitelistLoading(true);
    try {
      const result = await removeFromWhitelistAction(id);
      if (result.success) {
        setWhitelist(whitelist.filter((w) => w.id !== id));
        toast.success("Email removed from whitelist");
      } else {
        toast.error(result.error || "Failed to remove email");
      }
    } catch {
      toast.error("Failed to remove email");
    } finally {
      setWhitelistLoading(false);
    }
  };

  return (
    <div className="space-y-4">
      {/* Positions Section */}
      <Collapsible defaultOpen className="border rounded-xl overflow-hidden">
        <CollapsibleTrigger className="flex items-center justify-between w-full p-4 hover:bg-muted/50 transition-colors [&[data-state=open]>svg:first-child]:rotate-90">
          <div className="flex items-center gap-3">
            <ChevronRight className="h-4 w-4 transition-transform duration-200" />
            <div className="flex items-center gap-2">
              <MapPin className="h-4 w-4 text-muted-foreground" />
              <span className="font-medium">Positions</span>
            </div>
            <Badge variant="secondary" className="rounded-full">
              {positions.length}
            </Badge>
          </div>
          <PositionSheet
            itemId={item.id}
            positionSchemas={positionSchemas}
            onPositionCreated={(position) => {
              setPositions([...positions, position]);
            }}
            onSchemaCreated={(schema) => {
              setPositionSchemas([...positionSchemas, schema]);
            }}
          />
        </CollapsibleTrigger>
        <CollapsibleContent>
          <div className="px-4 pb-4 space-y-2">
            {positions.length === 0 ? (
              <p className="text-sm text-muted-foreground text-center py-4">
                No positions added yet.
              </p>
            ) : (
              positions.map((position) => (
                <div
                  key={position.id}
                  className="flex items-center justify-between p-3 bg-muted/30 rounded-lg"
                >
                  <div>
                    <p className="font-medium">
                      {position.positionSchema?.name || "Unknown Schema"}
                    </p>
                    <p className="text-sm text-muted-foreground">
                      {Object.entries(position.data)
                        .map(([k, v]) => `${k}: ${v}`)
                        .join(", ")}
                    </p>
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => handleDeletePosition(position.id)}
                    disabled={isPending}
                  >
                    {isPending ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      <Trash className="h-4 w-4 text-destructive" />
                    )}
                  </Button>
                </div>
              ))
            )}
          </div>
        </CollapsibleContent>
      </Collapsible>

      {/* Contents Section */}
      <Collapsible className="border rounded-xl overflow-hidden">
        <CollapsibleTrigger className="flex items-center justify-between w-full p-4 hover:bg-muted/50 transition-colors [&[data-state=open]>svg:first-child]:rotate-90">
          <div className="flex items-center gap-3">
            <ChevronRight className="h-4 w-4 transition-transform duration-200" />
            <div className="flex items-center gap-2">
              <File className="h-4 w-4 text-muted-foreground" />
              <span className="font-medium">Contents</span>
            </div>
            <Badge variant="secondary" className="rounded-full">
              {contents.length}
            </Badge>
          </div>
        </CollapsibleTrigger>
        <CollapsibleContent>
          <div className="px-4 pb-4 space-y-4">
            {contents.length === 0 ? (
              <p className="text-sm text-muted-foreground text-center py-4">
                No contents yet.
              </p>
            ) : (
              contents.map((content) => {
                const Icon = contentIcons[content.type];
                return (
                  <div key={content.id} className="border rounded-lg p-4 bg-muted/20">
                    <div className="flex items-center justify-between mb-4">
                      <div className="flex items-center gap-2">
                        <Icon className="h-5 w-5 text-muted-foreground" />
                        <h4 className="font-medium capitalize">{content.type}</h4>
                      </div>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleDeleteContent(content.id)}
                        disabled={contentLoading}
                      >
                        <Trash className="h-4 w-4 text-destructive" />
                      </Button>
                    </div>
                    <Form
                      schema={contentSchemas[content.type]}
                      formData={content.data}
                      validator={validator}
                      onSubmit={({ formData }) =>
                        handleUpdateContent(content.id, content.type, formData)
                      }
                      uiSchema={{
                        "ui:submitButtonOptions": {
                          norender: false,
                          submitText: "Save",
                          props: { disabled: contentLoading },
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
                  value={selectedContentType ?? ""}
                  onValueChange={(v) =>
                    setSelectedContentType(v as "file" | "image" | "video" | null)
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
                disabled={contentLoading || !selectedContentType}
              >
                {contentLoading ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <Plus className="h-4 w-4" />
                )}
              </Button>
            </div>
          </div>
        </CollapsibleContent>
      </Collapsible>

      {/* Children Section */}
      <Collapsible className="border rounded-xl overflow-hidden">
        <CollapsibleTrigger className="flex items-center justify-between w-full p-4 hover:bg-muted/50 transition-colors [&[data-state=open]>svg:first-child]:rotate-90">
          <div className="flex items-center gap-3">
            <ChevronRight className="h-4 w-4 transition-transform duration-200" />
            <div className="flex items-center gap-2">
              <Box className="h-4 w-4 text-muted-foreground" />
              <span className="font-medium">Child Items</span>
            </div>
            <Badge variant="secondary" className="rounded-full">
              {children.length}
            </Badge>
          </div>
          <Link
            href={`/items/new?parentId=${item.id}`}
            onClick={(e) => e.stopPropagation()}
          >
            <Button size="sm" variant="ghost" className="gap-1">
              <Plus className="h-4 w-4" />
              Add
            </Button>
          </Link>
        </CollapsibleTrigger>
        <CollapsibleContent>
          <div className="px-4 pb-4 space-y-2">
            {children.length === 0 ? (
              <p className="text-sm text-muted-foreground text-center py-4">
                No child items yet.
              </p>
            ) : (
              children.map((child) => (
                <Link
                  key={child.id}
                  href={`/items/${child.id}`}
                  className="flex items-center justify-between p-3 rounded-lg bg-muted/30 hover:bg-muted/50 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div>
                      <p className="font-medium">{child.title}</p>
                      {child.description && (
                        <p className="text-sm text-muted-foreground line-clamp-1">
                          {child.description}
                        </p>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    {child.category && (
                      <Badge variant="secondary">{child.category.name}</Badge>
                    )}
                    {child.visibility === "public" ? (
                      <Eye className="h-4 w-4 text-green-500" />
                    ) : (
                      <EyeOff className="h-4 w-4 text-muted-foreground" />
                    )}
                    <ExternalLink className="h-4 w-4 text-muted-foreground" />
                  </div>
                </Link>
              ))
            )}
          </div>
        </CollapsibleContent>
      </Collapsible>

      {/* Access Control Section (only for private items) */}
      {item.visibility === "private" && (
        <Collapsible className="border rounded-xl overflow-hidden">
          <CollapsibleTrigger className="flex items-center justify-between w-full p-4 hover:bg-muted/50 transition-colors [&[data-state=open]>svg:first-child]:rotate-90">
            <div className="flex items-center gap-3">
              <ChevronRight className="h-4 w-4 transition-transform duration-200" />
              <div className="flex items-center gap-2">
                <Mail className="h-4 w-4 text-muted-foreground" />
                <span className="font-medium">Access Control</span>
              </div>
              <Badge variant="secondary" className="rounded-full">
                {whitelist.length}
              </Badge>
            </div>
          </CollapsibleTrigger>
          <CollapsibleContent>
            <div className="px-4 pb-4 space-y-4">
              <p className="text-sm text-muted-foreground">
                Only these email addresses can view this private item.
              </p>

              {whitelist.length > 0 && (
                <div className="flex flex-wrap gap-2">
                  {whitelist.map((entry) => (
                    <Badge
                      key={entry.id}
                      variant="secondary"
                      className="flex items-center gap-1 pr-1"
                    >
                      {entry.email}
                      <button
                        onClick={() => handleRemoveEmail(entry.id)}
                        disabled={whitelistLoading}
                        className="ml-1 p-0.5 rounded-full hover:bg-muted"
                      >
                        <Trash className="h-3 w-3" />
                      </button>
                    </Badge>
                  ))}
                </div>
              )}

              {!showBulk ? (
                <div className="flex gap-2">
                  <Input
                    type="email"
                    placeholder="Enter email address"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") {
                        e.preventDefault();
                        handleAddEmail();
                      }
                    }}
                  />
                  <Button onClick={handleAddEmail} disabled={whitelistLoading}>
                    {whitelistLoading ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      <Plus className="h-4 w-4" />
                    )}
                  </Button>
                  <Button variant="outline" onClick={() => setShowBulk(true)}>
                    <Upload className="h-4 w-4" />
                  </Button>
                </div>
              ) : (
                <div className="space-y-2">
                  <Textarea
                    placeholder="Enter emails (one per line, or comma/semicolon separated)"
                    value={bulkEmails}
                    onChange={(e) => setBulkEmails(e.target.value)}
                    rows={5}
                  />
                  <div className="flex gap-2">
                    <Button onClick={handleBulkAdd} disabled={whitelistLoading}>
                      {whitelistLoading ? (
                        <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                      ) : (
                        <Plus className="h-4 w-4 mr-2" />
                      )}
                      Add All
                    </Button>
                    <Button
                      variant="outline"
                      onClick={() => {
                        setShowBulk(false);
                        setBulkEmails("");
                      }}
                    >
                      Cancel
                    </Button>
                  </div>
                </div>
              )}
            </div>
          </CollapsibleContent>
        </Collapsible>
      )}
    </div>
  );
}
