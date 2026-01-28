"use client";

import { useState, useRef, useCallback } from "react";
import Image from "next/image";
import { Upload, X, Loader2, AlertCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { toast } from "sonner";
import {
  getImageUploadUrlAction,
  deleteImageAction,
} from "@/lib/actions/s3-upload-actions";

interface ImageUploadProps {
  value: string[];
  onChange: (urls: string[]) => void;
  maxImages?: number;
  maxSizeMB?: number;
  disabled?: boolean;
  className?: string;
}

interface UploadingImage {
  id: string;
  file: File;
  preview: string;
  progress: number;
  error?: string;
}

export function ImageUpload({
  value = [],
  onChange,
  maxImages = 10,
  maxSizeMB = 5,
  disabled = false,
  className,
}: ImageUploadProps) {
  const [uploading, setUploading] = useState<UploadingImage[]>([]);
  const [isDragOver, setIsDragOver] = useState(false);
  const [deletingUrls, setDeletingUrls] = useState<Set<string>>(new Set());
  const fileInputRef = useRef<HTMLInputElement>(null);

  const canAddMore = value.length + uploading.length < maxImages;

  const uploadFile = useCallback(
    async (file: File): Promise<string | null> => {
      const uploadId = crypto.randomUUID();
      const preview = URL.createObjectURL(file);

      setUploading((prev) => [
        ...prev,
        { id: uploadId, file, preview, progress: 0 },
      ]);

      try {
        const result = await getImageUploadUrlAction(
          file.name,
          file.type,
          "items"
        );

        if (!result.success || !result.data) {
          throw new Error(result.error || "Failed to get upload URL");
        }

        const { uploadUrl, publicUrl } = result.data;

        await new Promise<void>((resolve, reject) => {
          const xhr = new XMLHttpRequest();

          xhr.upload.addEventListener("progress", (event) => {
            if (event.lengthComputable) {
              const progress = Math.round((event.loaded / event.total) * 100);
              setUploading((prev) =>
                prev.map((u) => (u.id === uploadId ? { ...u, progress } : u))
              );
            }
          });

          xhr.addEventListener("load", () => {
            if (xhr.status >= 200 && xhr.status < 300) {
              resolve();
            } else {
              reject(new Error(`Upload failed: ${xhr.status}`));
            }
          });

          xhr.addEventListener("error", () => {
            reject(new Error("Network error during upload"));
          });

          xhr.open("PUT", uploadUrl);
          xhr.setRequestHeader("Content-Type", file.type);
          xhr.send(file);
        });

        setUploading((prev) => prev.filter((u) => u.id !== uploadId));
        URL.revokeObjectURL(preview);

        return publicUrl;
      } catch (error) {
        setUploading((prev) =>
          prev.map((u) =>
            u.id === uploadId
              ? { ...u, error: error instanceof Error ? error.message : "Upload failed" }
              : u
          )
        );
        return null;
      }
    },
    []
  );

  const handleFiles = useCallback(
    async (files: FileList | File[]) => {
      const fileArray = Array.from(files);
      const availableSlots = maxImages - value.length - uploading.length;

      if (fileArray.length > availableSlots) {
        toast.error(`Can only add ${availableSlots} more images`);
        return;
      }

      const validFiles: File[] = [];
      for (const file of fileArray) {
        if (!file.type.startsWith("image/")) {
          toast.error(`${file.name} is not an image`);
          continue;
        }
        if (file.size > maxSizeMB * 1024 * 1024) {
          toast.error(`${file.name} exceeds ${maxSizeMB}MB limit`);
          continue;
        }
        validFiles.push(file);
      }

      if (validFiles.length === 0) return;

      const results = await Promise.all(validFiles.map(uploadFile));
      const successfulUrls = results.filter((url): url is string => url !== null);

      if (successfulUrls.length > 0) {
        onChange([...value, ...successfulUrls]);
      }

      if (successfulUrls.length < validFiles.length) {
        toast.error(`${validFiles.length - successfulUrls.length} uploads failed`);
      }
    },
    [value, uploading.length, maxImages, maxSizeMB, onChange, uploadFile]
  );

  const handleRemove = useCallback(
    async (url: string) => {
      setDeletingUrls((prev) => new Set(prev).add(url));
      onChange(value.filter((u) => u !== url));

      const result = await deleteImageAction(url);
      if (!result.success) {
        console.warn("Failed to delete image from R2:", result.error);
      }

      setDeletingUrls((prev) => {
        const next = new Set(prev);
        next.delete(url);
        return next;
      });
    },
    [value, onChange]
  );

  const handleRemoveUploading = useCallback((id: string) => {
    setUploading((prev) => {
      const item = prev.find((u) => u.id === id);
      if (item) {
        URL.revokeObjectURL(item.preview);
      }
      return prev.filter((u) => u.id !== id);
    });
  }, []);

  const handleDragOver = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      e.stopPropagation();
      if (!disabled && canAddMore) {
        setIsDragOver(true);
      }
    },
    [disabled, canAddMore]
  );

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragOver(false);
  }, []);

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      e.stopPropagation();
      setIsDragOver(false);

      if (disabled || !canAddMore) return;

      const files = e.dataTransfer.files;
      if (files.length > 0) {
        handleFiles(files);
      }
    },
    [disabled, canAddMore, handleFiles]
  );

  const handleInputChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const files = e.target.files;
      if (files && files.length > 0) {
        handleFiles(files);
      }
      e.target.value = "";
    },
    [handleFiles]
  );

  const moveImage = useCallback(
    (fromIndex: number, direction: "left" | "right") => {
      const toIndex = direction === "left" ? fromIndex - 1 : fromIndex + 1;
      if (toIndex < 0 || toIndex >= value.length) return;

      const newValue = [...value];
      const [moved] = newValue.splice(fromIndex, 1);
      newValue.splice(toIndex, 0, moved);
      onChange(newValue);
    },
    [value, onChange]
  );

  return (
    <div className={cn("space-y-4", className)}>
      {(value.length > 0 || uploading.length > 0) && (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
          {value.map((url, index) => (
            <div
              key={url}
              className="relative aspect-square rounded-lg border bg-muted overflow-hidden group"
            >
              <Image
                src={url}
                alt={`Image ${index + 1}`}
                fill
                className="object-cover"
                sizes="(max-width: 640px) 50vw, (max-width: 768px) 33vw, 25vw"
              />
              {!disabled && (
                <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-1">
                  {index > 0 && (
                    <Button
                      type="button"
                      variant="secondary"
                      size="icon"
                      className="h-8 w-8"
                      onClick={() => moveImage(index, "left")}
                    >
                      &larr;
                    </Button>
                  )}
                  <Button
                    type="button"
                    variant="secondary"
                    size="icon"
                    className="h-8 w-8"
                    onClick={() => handleRemove(url)}
                    disabled={deletingUrls.has(url)}
                  >
                    {deletingUrls.has(url) ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      <X className="h-4 w-4" />
                    )}
                  </Button>
                  {index < value.length - 1 && (
                    <Button
                      type="button"
                      variant="secondary"
                      size="icon"
                      className="h-8 w-8"
                      onClick={() => moveImage(index, "right")}
                    >
                      &rarr;
                    </Button>
                  )}
                </div>
              )}
              {index === 0 && (
                <span className="absolute bottom-2 left-2 bg-primary text-primary-foreground text-xs px-2 py-1 rounded">
                  Main
                </span>
              )}
            </div>
          ))}

          {uploading.map((item) => (
            <div
              key={item.id}
              className="relative aspect-square rounded-lg border bg-muted overflow-hidden"
            >
              <Image
                src={item.preview}
                alt="Uploading"
                fill
                className="object-cover opacity-50"
              />
              <div className="absolute inset-0 flex flex-col items-center justify-center">
                {item.error ? (
                  <>
                    <AlertCircle className="h-6 w-6 text-destructive mb-2" />
                    <span className="text-xs text-destructive text-center px-2">
                      {item.error}
                    </span>
                    <Button
                      type="button"
                      variant="secondary"
                      size="sm"
                      className="mt-2"
                      onClick={() => handleRemoveUploading(item.id)}
                    >
                      Remove
                    </Button>
                  </>
                ) : (
                  <>
                    <Loader2 className="h-6 w-6 animate-spin text-primary mb-2" />
                    <span className="text-sm font-medium">{item.progress}%</span>
                  </>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {canAddMore && (
        <>
          <input
            type="file"
            ref={fileInputRef}
            className="hidden"
            accept="image/*"
            multiple
            onChange={handleInputChange}
            disabled={disabled}
          />
          <div
            className={cn(
              "flex cursor-pointer flex-col items-center gap-2 rounded-lg border border-dashed p-6 text-center transition-colors",
              isDragOver && "border-primary bg-primary/5",
              disabled && "cursor-not-allowed opacity-50"
            )}
            onClick={() => !disabled && fileInputRef.current?.click()}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
          >
            <Upload className="h-8 w-8 text-muted-foreground" />
            <div className="text-sm text-muted-foreground">
              <span className="font-medium text-foreground">Click to upload</span>{" "}
              or drag and drop
            </div>
            <p className="text-xs text-muted-foreground">
              Images up to {maxSizeMB}MB ({value.length}/{maxImages})
            </p>
          </div>
        </>
      )}
    </div>
  );
}
