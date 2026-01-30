/**
 * Parse file IDs from images array
 * Images can be either "file:123" format or legacy URLs
 */
export function parseFileIds(images: string[]): number[] {
  const fileIds: number[] = [];
  for (const image of images) {
    if (image.startsWith("file:")) {
      const id = parseInt(image.substring(5), 10);
      if (!isNaN(id)) {
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
