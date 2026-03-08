import { FFmpeg } from "@ffmpeg/ffmpeg";
import { fetchFile, toBlobURL } from "@ffmpeg/util";

let ffmpeg: FFmpeg | null = null;
let loadPromise: Promise<void> | null = null;

/**
 * Get or initialize the singleton FFmpeg WASM instance.
 * Uses single-threaded core for reliability (mt can deadlock with credentialless COEP).
 */
async function getFFmpeg(): Promise<FFmpeg> {
  if (ffmpeg && ffmpeg.loaded) return ffmpeg;

  if (loadPromise) {
    await loadPromise;
    return ffmpeg!;
  }

  ffmpeg = new FFmpeg();

  loadPromise = (async () => {
    console.log("[ffmpeg] Loading FFmpeg WASM (single-threaded)...");
    const baseURL =
      "https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.10/dist/umd";
    await ffmpeg!.load({
      coreURL: await toBlobURL(`${baseURL}/ffmpeg-core.js`, "text/javascript"),
      wasmURL: await toBlobURL(
        `${baseURL}/ffmpeg-core.wasm`,
        "application/wasm",
      ),
    });
    console.log("[ffmpeg] FFmpeg WASM loaded successfully");
  })();

  await loadPromise;
  return ffmpeg!;
}

/**
 * Collect FFmpeg log output during an operation for error reporting.
 */
function createLogCollector(ff: FFmpeg): {
  logs: string[];
  attach: () => void;
  detach: () => void;
} {
  const logs: string[] = [];
  const handler = ({ message }: { message: string }) => {
    logs.push(message);
  };
  return {
    logs,
    attach: () => ff.on("log", handler),
    detach: () => ff.off("log", handler),
  };
}

/**
 * Clean up FFmpeg virtual filesystem entries, ignoring errors.
 */
async function cleanupFiles(ff: FFmpeg, ...names: string[]) {
  for (const name of names) {
    try {
      await ff.deleteFile(name);
    } catch {
      // file may not exist
    }
  }
}

export type ProgressCallback = (progress: number) => void;

/**
 * Attach an FFmpeg progress listener and return a detach function.
 * Progress is 0–1.
 */
function attachProgress(ff: FFmpeg, onProgress?: ProgressCallback): () => void {
  if (!onProgress) return () => {};
  const handler = ({ progress }: { progress: number }) => {
    onProgress(Math.min(1, Math.max(0, progress)));
  };
  ff.on("progress", handler);
  return () => ff.off("progress", handler);
}

/**
 * Generate a JPEG thumbnail from a video file (frame at 1s, 480px width).
 * Falls back to frame at 0s if 1s extraction fails.
 */
export async function generateVideoThumbnail(
  file: File,
  onProgress?: ProgressCallback,
): Promise<Blob> {
  const ff = await getFFmpeg();
  const inputName = "input" + getExtension(file.name);
  const outputName = "thumb.jpg";

  console.log(`[ffmpeg] generateVideoThumbnail: ${file.name}`);
  await ff.writeFile(inputName, await fetchFile(file));

  const log = createLogCollector(ff);
  log.attach();
  const detachProgress = attachProgress(ff, onProgress);

  console.log("[ffmpeg] generateVideoThumbnail: trying frame at 1s...");
  let exitCode = await ff.exec([
    "-y",
    "-i",
    inputName,
    "-ss",
    "00:00:01",
    "-vframes",
    "1",
    "-vf",
    "scale=480:-1",
    outputName,
  ]);

  if (exitCode !== 0) {
    console.log(
      "[ffmpeg] generateVideoThumbnail: 1s failed, trying frame at 0s...",
    );
    exitCode = await ff.exec([
      "-y",
      "-i",
      inputName,
      "-vframes",
      "1",
      "-vf",
      "scale=480:-1",
      outputName,
    ]);
  }

  detachProgress();
  log.detach();

  if (exitCode !== 0) {
    console.error(
      "[ffmpeg] generateVideoThumbnail failed:",
      log.logs.slice(-5).join("\n"),
    );
    await cleanupFiles(ff, inputName, outputName);
    throw new Error(
      `FFmpeg thumbnail failed (exit ${exitCode}): ${log.logs.slice(-3).join(" | ")}`,
    );
  }

  const data = (await ff.readFile(outputName)) as Uint8Array;
  await cleanupFiles(ff, inputName, outputName);
  console.log(
    `[ffmpeg] generateVideoThumbnail: done (${data.byteLength} bytes)`,
  );

  return new Blob([new Uint8Array(data)], { type: "image/jpeg" });
}

/**
 * Generate a JPEG preview from an image file (480px width).
 */
export async function generateImagePreview(
  file: File,
  onProgress?: ProgressCallback,
): Promise<Blob> {
  const ff = await getFFmpeg();
  const inputName = "input" + getExtension(file.name);
  const outputName = "preview.jpg";

  console.log(`[ffmpeg] generateImagePreview: ${file.name}`);
  await ff.writeFile(inputName, await fetchFile(file));

  const log = createLogCollector(ff);
  log.attach();
  const detachProgress = attachProgress(ff, onProgress);
  const exitCode = await ff.exec([
    "-y",
    "-i",
    inputName,
    "-vf",
    "scale=480:-1",
    "-q:v",
    "5",
    outputName,
  ]);
  detachProgress();
  log.detach();

  if (exitCode !== 0) {
    console.error(
      "[ffmpeg] generateImagePreview failed:",
      log.logs.slice(-5).join("\n"),
    );
    await cleanupFiles(ff, inputName, outputName);
    throw new Error(
      `FFmpeg image preview failed (exit ${exitCode}): ${log.logs.slice(-3).join(" | ")}`,
    );
  }

  const data = (await ff.readFile(outputName)) as Uint8Array;
  await cleanupFiles(ff, inputName, outputName);
  console.log(`[ffmpeg] generateImagePreview: done (${data.byteLength} bytes)`);

  return new Blob([new Uint8Array(data)], { type: "image/jpeg" });
}

/**
 * Get video duration in seconds.
 * Uses `-i input` with no output — ffmpeg reads metadata and exits with error code 1
 * but logs contain the duration. This avoids transcoding the entire file.
 */
export async function getVideoDuration(file: File): Promise<number> {
  const ff = await getFFmpeg();
  const inputName = "input" + getExtension(file.name);

  console.log(
    `[ffmpeg] getVideoDuration: writing file ${file.name} (${(file.size / 1024 / 1024).toFixed(1)}MB)`,
  );
  await ff.writeFile(inputName, await fetchFile(file));

  let duration = 0;
  const logs: string[] = [];

  const logHandler = ({ message }: { message: string }) => {
    logs.push(message);
  };
  ff.on("log", logHandler);

  console.log("[ffmpeg] getVideoDuration: probing metadata (no transcode)...");
  await ff.exec(["-i", inputName]).catch(() => {
    // Expected: ffmpeg exits with error when no output specified
  });

  ff.off("log", logHandler);
  await cleanupFiles(ff, inputName);

  for (const line of logs) {
    const match = line.match(/Duration:\s*(\d+):(\d+):(\d+)\.(\d+)/);
    if (match) {
      const hours = parseInt(match[1]);
      const minutes = parseInt(match[2]);
      const seconds = parseInt(match[3]);
      const ms = parseInt(match[4]);
      duration = hours * 3600 + minutes * 60 + seconds + ms / 100;
      break;
    }
  }

  console.log(`[ffmpeg] getVideoDuration: ${duration}s`);
  return duration;
}

/**
 * Compress video to H.264, max 720p, 5-min limit, AAC audio.
 */
export async function compressVideo(
  file: File,
  onProgress?: ProgressCallback,
): Promise<Blob> {
  const ff = await getFFmpeg();
  const inputName = "input" + getExtension(file.name);
  const outputName = "compressed.mp4";

  console.log(
    `[ffmpeg] compressVideo: ${file.name} (${(file.size / 1024 / 1024).toFixed(1)}MB)`,
  );
  await ff.writeFile(inputName, await fetchFile(file));

  const log = createLogCollector(ff);
  log.attach();
  const detachProgress = attachProgress(ff, onProgress);
  console.log("[ffmpeg] compressVideo: starting transcode...");
  const exitCode = await ff.exec([
    "-y",
    "-i",
    inputName,
    "-t",
    "300",
    "-vf",
    "scale='min(720,iw)':-2",
    "-c:v",
    "libx264",
    "-preset",
    "fast",
    "-crf",
    "28",
    "-c:a",
    "aac",
    "-b:a",
    "96k",
    "-movflags",
    "+faststart",
    outputName,
  ]);
  detachProgress();
  log.detach();

  if (exitCode !== 0) {
    console.error(
      "[ffmpeg] compressVideo failed:",
      log.logs.slice(-5).join("\n"),
    );
    await cleanupFiles(ff, inputName, outputName);
    throw new Error(
      `FFmpeg compress failed (exit ${exitCode}): ${log.logs.slice(-3).join(" | ")}`,
    );
  }

  const data = (await ff.readFile(outputName)) as Uint8Array;
  await cleanupFiles(ff, inputName, outputName);
  console.log(
    `[ffmpeg] compressVideo: done (${(data.byteLength / 1024 / 1024).toFixed(1)}MB)`,
  );

  return new Blob([new Uint8Array(data)], { type: "video/mp4" });
}

/**
 * MIME type lookup by file extension.
 */
export function mimeTypeForExtension(ext: string): string {
  const map: Record<string, string> = {
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    png: "image/png",
    gif: "image/gif",
    webp: "image/webp",
    heic: "image/heic",
    mp4: "video/mp4",
    mov: "video/quicktime",
    avi: "video/x-msvideo",
    mkv: "video/x-matroska",
    webm: "video/webm",
  };
  return map[ext.toLowerCase()] || "application/octet-stream";
}

export function isVideoMime(mime: string): boolean {
  return mime.startsWith("video/");
}

export function isImageMime(mime: string): boolean {
  return mime.startsWith("image/");
}

/**
 * Upload a blob to a presigned URL with progress tracking via XMLHttpRequest.
 */
export function uploadWithProgress(
  url: string,
  body: Blob,
  contentType: string,
  onProgress?: ProgressCallback,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open("PUT", url);
    xhr.setRequestHeader("Content-Type", contentType);

    if (onProgress) {
      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
          onProgress(Math.min(1, e.loaded / e.total));
        }
      };
    }

    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        resolve();
      } else {
        reject(new Error(`Upload failed: ${xhr.status}`));
      }
    };

    xhr.onerror = () => reject(new Error("Upload network error"));
    xhr.send(body);
  });
}

function getExtension(filename: string): string {
  const dot = filename.lastIndexOf(".");
  return dot >= 0 ? filename.substring(dot) : "";
}
