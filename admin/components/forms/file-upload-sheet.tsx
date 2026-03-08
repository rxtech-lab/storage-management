"use client";

import { useState, useRef, useCallback, useEffect } from "react";
import { useRouter } from "next/navigation";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Upload,
  Loader2,
  CheckCircle2,
  XCircle,
  Image,
  Video,
} from "lucide-react";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import {
  mimeTypeForExtension,
  isVideoMime,
  generateVideoThumbnail,
  generateImagePreview,
  getVideoDuration,
  compressVideo,
  type ProgressCallback,
  uploadWithProgress,
} from "@/lib/utils/ffmpeg-wasm";

type Step = "selectFiles" | "fileList" | "uploading" | "done";
type VideoUploadMode = "imageOnly" | "videoAndImage";

interface FileEntry {
  file: File;
  name: string;
  ext: string;
  mime: string;
  type: "image" | "video";
  size: number;
}

interface UploadResult {
  filename: string;
  success: boolean;
  error?: string;
}

interface FileUploadSheetProps {
  itemId: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onComplete?: () => void;
}

export function FileUploadSheet({
  itemId,
  open,
  onOpenChange,
  onComplete,
}: FileUploadSheetProps) {
  const router = useRouter();
  const [step, setStep] = useState<Step>("selectFiles");
  const [files, setFiles] = useState<FileEntry[]>([]);
  const [videoMode, setVideoMode] = useState<VideoUploadMode>("imageOnly");
  const [progress, setProgress] = useState(0);
  const [total, setTotal] = useState(0);
  const [results, setResults] = useState<UploadResult[]>([]);
  const [currentFile, setCurrentFile] = useState("");
  const [fileProgress, setFileProgress] = useState(0);
  const [filePhase, setFilePhase] = useState("");
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [showCloseConfirm, setShowCloseConfirm] = useState(false);

  // Prevent browser refresh/close during upload
  useEffect(() => {
    if (step !== "uploading") return;
    const handler = (e: BeforeUnloadEvent) => {
      e.preventDefault();
    };
    window.addEventListener("beforeunload", handler);
    return () => window.removeEventListener("beforeunload", handler);
  }, [step]);

  const reset = useCallback(() => {
    setStep("selectFiles");
    setFiles([]);
    setVideoMode("imageOnly");
    setProgress(0);
    setTotal(0);
    setResults([]);
    setCurrentFile("");
    setFileProgress(0);
    setFilePhase("");
  }, []);

  const handleOpenChange = useCallback(
    (isOpen: boolean) => {
      if (!isOpen) reset();
      onOpenChange(isOpen);
    },
    [onOpenChange, reset],
  );

  const handleFileSelect = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const selectedFiles = e.target.files;
      if (!selectedFiles || selectedFiles.length === 0) return;

      const entries: FileEntry[] = [];
      for (let i = 0; i < selectedFiles.length; i++) {
        const file = selectedFiles[i];
        const ext = file.name.split(".").pop()?.toLowerCase() || "";
        const mime = mimeTypeForExtension(ext);
        const isVideo = isVideoMime(mime);
        const isImage = mime.startsWith("image/");

        if (isVideo || isImage) {
          entries.push({
            file,
            name: file.name,
            ext,
            mime,
            type: isVideo ? "video" : "image",
            size: file.size,
          });
        }
      }

      if (entries.length === 0) {
        toast.error("No supported image or video files selected");
        return;
      }

      entries.sort((a, b) => a.name.localeCompare(b.name));
      setFiles(entries);
      setStep("fileList");
    },
    [],
  );

  const processAndUploadFile = useCallback(
    async (
      file: FileEntry,
      index: number,
      totalCount: number,
      uploadMode: VideoUploadMode,
    ): Promise<UploadResult> => {
      setCurrentFile(`[${index + 1}/${totalCount}] ${file.name}`);
      setFileProgress(0);

      const onProgress: ProgressCallback = (p) => setFileProgress(p);

      try {
        let thumbnailBlob: Blob;
        let videoDuration: number | undefined;
        let compressedVideoBlob: Blob | undefined;

        if (file.type === "video") {
          setFilePhase("Probing duration...");
          videoDuration = await getVideoDuration(file.file);

          setFilePhase("Generating thumbnail...");
          setFileProgress(0);
          thumbnailBlob = await generateVideoThumbnail(file.file, onProgress);

          if (uploadMode === "videoAndImage") {
            setFilePhase("Compressing video...");
            setFileProgress(0);
            compressedVideoBlob = await compressVideo(file.file, onProgress);
          }
        } else {
          setFilePhase("Generating preview...");
          thumbnailBlob = await generateImagePreview(file.file, onProgress);
        }

        setFilePhase("Requesting upload URLs...");

        const requestBody = {
          item_id: itemId,
          items: [
            {
              filename: file.name,
              type: file.type,
              title: file.name,
              mime_type: file.mime,
              size: file.size,
              file_path: file.name,
              ...(file.type === "video" && videoDuration != null
                ? { video_length: videoDuration }
                : {}),
            },
          ],
        };

        const response = await fetch("/api/v1/upload/content-preview", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(requestBody),
        });

        if (!response.ok) {
          const err = await response.json().catch(() => ({}));
          throw new Error(err.error || `API error: ${response.status}`);
        }

        const presignedResults: {
          id: string;
          imageUrl: string;
          videoUrl?: string;
        }[] = await response.json();
        const presigned = presignedResults[0];

        if (!presigned) {
          throw new Error("No presigned URL returned");
        }

        setFilePhase("Uploading thumbnail...");
        setFileProgress(0);
        await uploadWithProgress(
          presigned.imageUrl,
          thumbnailBlob,
          "image/jpeg",
          onProgress,
        );

        if (compressedVideoBlob && presigned.videoUrl) {
          setFilePhase("Uploading video...");
          setFileProgress(0);
          await uploadWithProgress(
            presigned.videoUrl,
            compressedVideoBlob,
            file.mime,
            onProgress,
          );
        }

        return { filename: file.name, success: true };
      } catch (error) {
        const msg =
          error instanceof Error
            ? error.message
            : typeof error === "string"
              ? error
              : String(error);
        console.error(`Upload failed for ${file.name}:`, error);
        return { filename: file.name, success: false, error: msg };
      }
    },
    [itemId],
  );

  const startUpload = useCallback(
    async (mode: VideoUploadMode) => {
      setVideoMode(mode);
      setStep("uploading");
      setTotal(files.length);
      setProgress(0);
      setResults([]);

      const allResults: UploadResult[] = [];

      for (let i = 0; i < files.length; i++) {
        const result = await processAndUploadFile(
          files[i],
          i,
          files.length,
          mode,
        );
        allResults.push(result);
        setProgress(i + 1);
        setResults([...allResults]);
      }

      setCurrentFile("");
      setStep("done");
      onComplete?.();
      router.refresh();
    },
    [files, processAndUploadFile, onComplete, router],
  );

  const hasVideos = files.some((f) => f.type === "video");
  const imageCount = files.filter((f) => f.type === "image").length;
  const videoCount = files.filter((f) => f.type === "video").length;
  const successCount = results.filter((r) => r.success).length;
  const failCount = results.filter((r) => !r.success).length;

  return (
    <Sheet
      open={open}
      onOpenChange={(isOpen) => {
        if (!isOpen && step === "uploading") {
          setShowCloseConfirm(true);
          return;
        }
        handleOpenChange(isOpen);
      }}
    >
      <SheetContent
        className="sm:max-w-lg max-w-3xl overflow-y-auto"
        onInteractOutside={(e) => {
          if (step === "uploading") e.preventDefault();
        }}
        onEscapeKeyDown={(e) => {
          if (step === "uploading") {
            e.preventDefault();
            setShowCloseConfirm(true);
          }
        }}
      >
        <SheetHeader>
          <SheetTitle>Upload Files</SheetTitle>
          <SheetDescription>
            Select image or video files to upload as content previews.
          </SheetDescription>
        </SheetHeader>

        <div className="space-y-4 px-2 pb-6">
          {/* Step: Select Files */}
          {step === "selectFiles" && (
            <div className="space-y-4">
              <input
                ref={fileInputRef}
                type="file"
                multiple
                accept="image/*,video/*"
                className="hidden"
                onChange={handleFileSelect}
              />
              <Button
                onClick={() => fileInputRef.current?.click()}
                variant="outline"
                className="w-full h-32 flex flex-col gap-2"
              >
                <Upload className="h-8 w-8 text-muted-foreground" />
                <span>Select Files</span>
                <span className="text-xs text-muted-foreground">
                  Images and videos
                </span>
              </Button>
            </div>
          )}

          {/* Step: File List */}
          {step === "fileList" && (
            <div className="space-y-4">
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium">
                  {files.length} file(s) selected
                </span>
                {imageCount > 0 && (
                  <Badge variant="secondary" className="gap-1">
                    <Image className="h-3 w-3" />
                    {imageCount}
                  </Badge>
                )}
                {videoCount > 0 && (
                  <Badge variant="secondary" className="gap-1">
                    <Video className="h-3 w-3" />
                    {videoCount}
                  </Badge>
                )}
              </div>

              <div className="max-h-48 overflow-y-auto space-y-1 border rounded-lg p-2">
                {files.slice(0, 50).map((f, i) => (
                  <div
                    key={i}
                    className="flex items-center gap-2 text-sm py-0.5"
                  >
                    {f.type === "video" ? (
                      <Video className="h-3.5 w-3.5 text-muted-foreground flex-shrink-0" />
                    ) : (
                      <Image className="h-3.5 w-3.5 text-muted-foreground flex-shrink-0" />
                    )}
                    <span className="truncate">{f.name}</span>
                    <span className="text-muted-foreground text-xs ml-auto flex-shrink-0">
                      {(f.size / 1024 / 1024).toFixed(1)}MB
                    </span>
                  </div>
                ))}
                {files.length > 50 && (
                  <p className="text-xs text-muted-foreground text-center py-1">
                    ... and {files.length - 50} more
                  </p>
                )}
              </div>

              {hasVideos ? (
                <div className="space-y-2">
                  <Label>Video upload mode</Label>
                  <div className="flex gap-2">
                    <Button
                      variant="outline"
                      onClick={() => setStep("selectFiles")}
                    >
                      Back
                    </Button>
                    <Button
                      variant="outline"
                      onClick={() => startUpload("imageOnly")}
                    >
                      Thumbnails only
                    </Button>
                    <Button onClick={() => startUpload("videoAndImage")}>
                      Video + Thumbnails
                    </Button>
                  </div>
                </div>
              ) : (
                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    onClick={() => setStep("selectFiles")}
                  >
                    Back
                  </Button>
                  <Button onClick={() => startUpload("imageOnly")}>
                    Upload
                  </Button>
                </div>
              )}
            </div>
          )}

          {/* Step: Uploading */}
          {step === "uploading" && (
            <div className="space-y-4">
              <div className="flex items-center gap-2">
                <Loader2 className="h-4 w-4 animate-spin" />
                <span className="text-sm font-medium">
                  Processing... {progress}/{total}
                </span>
              </div>

              <div className="w-full bg-muted rounded-full h-2">
                <div
                  className="bg-primary h-2 rounded-full transition-all duration-300"
                  style={{
                    width: `${total > 0 ? (progress / total) * 100 : 0}%`,
                  }}
                />
              </div>

              {currentFile && (
                <div className="space-y-1">
                  <p className="text-xs text-muted-foreground truncate">
                    {currentFile}
                  </p>
                  {filePhase && (
                    <div className="space-y-1">
                      <div className="flex items-center justify-between">
                        <span className="text-xs text-muted-foreground">
                          {filePhase}
                        </span>
                        <span className="text-xs text-muted-foreground tabular-nums">
                          {Math.round(fileProgress * 100)}%
                        </span>
                      </div>
                      <div className="w-full bg-muted rounded-full h-1.5">
                        <div
                          className="bg-blue-500 h-1.5 rounded-full transition-all duration-150"
                          style={{ width: `${fileProgress * 100}%` }}
                        />
                      </div>
                    </div>
                  )}
                </div>
              )}

              {results.length > 0 && (
                <div className="max-h-32 overflow-y-auto space-y-0.5 text-xs">
                  {results.map((r, i) => (
                    <div key={i} className="flex items-center gap-1.5">
                      {r.success ? (
                        <CheckCircle2 className="h-3 w-3 text-green-500 flex-shrink-0" />
                      ) : (
                        <XCircle className="h-3 w-3 text-destructive flex-shrink-0" />
                      )}
                      <span className="truncate">{r.filename}</span>
                      {r.error && (
                        <span className="text-destructive ml-auto flex-shrink-0">
                          {r.error}
                        </span>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* Step: Done */}
          {step === "done" && (
            <div className="space-y-4">
              <div className="flex items-center gap-2">
                <CheckCircle2 className="h-5 w-5 text-green-500" />
                <span className="font-medium">Upload Complete</span>
              </div>

              <div className="flex gap-3">
                <Badge
                  variant="secondary"
                  className="gap-1 text-green-600 bg-green-50"
                >
                  <CheckCircle2 className="h-3 w-3" />
                  {successCount} succeeded
                </Badge>
                {failCount > 0 && (
                  <Badge
                    variant="secondary"
                    className="gap-1 text-destructive bg-red-50"
                  >
                    <XCircle className="h-3 w-3" />
                    {failCount} failed
                  </Badge>
                )}
              </div>

              <div className="max-h-48 overflow-y-auto space-y-0.5 border rounded-lg p-2 text-sm">
                {results.map((r, i) => (
                  <div key={i} className="flex items-center gap-2 py-0.5">
                    {r.success ? (
                      <CheckCircle2 className="h-3.5 w-3.5 text-green-500 flex-shrink-0" />
                    ) : (
                      <XCircle className="h-3.5 w-3.5 text-destructive flex-shrink-0" />
                    )}
                    <span className="truncate">{r.filename}</span>
                    {r.error && (
                      <span className="text-xs text-destructive ml-auto">
                        {r.error}
                      </span>
                    )}
                  </div>
                ))}
              </div>

              <Button onClick={() => handleOpenChange(false)}>Close</Button>
            </div>
          )}
        </div>
      </SheetContent>
      <AlertDialog open={showCloseConfirm} onOpenChange={setShowCloseConfirm}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Upload in progress</AlertDialogTitle>
            <AlertDialogDescription>
              Files are still being uploaded. Closing now will cancel the
              remaining uploads. Are you sure?
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Continue uploading</AlertDialogCancel>
            <AlertDialogAction
              variant="destructive"
              onClick={() => handleOpenChange(false)}
            >
              Stop and close
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </Sheet>
  );
}
