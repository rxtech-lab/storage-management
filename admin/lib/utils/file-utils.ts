/**
 * Parse file IDs from images array
 * Images can be either "file:abc123" format or legacy URLs
 */
export function parseFileIds(images: string[]): string[] {
  const fileIds: string[] = [];
  for (const image of images) {
    if (image.startsWith("file:")) {
      const id = image.substring(5);
      if (id) {
        fileIds.push(id);
      }
    }
  }
  return fileIds;
}

/**
 * Check if an image string is a file ID reference
 */
export function isFileId(image: string): boolean {
  return image.startsWith("file:");
}
