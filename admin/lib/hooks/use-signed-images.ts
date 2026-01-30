"use client";

import { useState, useEffect, useCallback, useMemo } from "react";
import { signImagesArray } from "@/lib/actions/s3-upload-actions";

interface UseSignedImagesOptions {
  expiresIn?: number; // seconds
  refreshBuffer?: number; // seconds before expiry to refresh
}

interface UseSignedImagesReturn {
  signedUrls: Map<string, string>;
  isLoading: boolean;
  error: string | null;
  refreshUrls: () => Promise<void>;
}

export function useSignedImages(
  publicUrls: string[],
  options: UseSignedImagesOptions = {}
): UseSignedImagesReturn {
  const { expiresIn = 3600, refreshBuffer = 300 } = options;

  const [signedUrls, setSignedUrls] = useState<Map<string, string>>(new Map());
  const [expiresAt, setExpiresAt] = useState<Date | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Memoize the URLs array to avoid unnecessary re-fetches
  const urlsKey = useMemo(() => publicUrls.join(","), [publicUrls]);

  const fetchSignedUrls = useCallback(async () => {
    if (publicUrls.length === 0) {
      setSignedUrls(new Map());
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      // signImagesArray handles both file IDs (file:123) and legacy URLs
      const signedUrlsArray = await signImagesArray(publicUrls, expiresIn);

      const urlMap = new Map<string, string>();
      publicUrls.forEach((originalRef, index) => {
        if (signedUrlsArray[index]) {
          urlMap.set(originalRef, signedUrlsArray[index]);
        }
      });
      setSignedUrls(urlMap);

      // Set expiry time
      setExpiresAt(new Date(Date.now() + expiresIn * 1000));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
    } finally {
      setIsLoading(false);
    }
  }, [urlsKey, expiresIn]);

  // Initial fetch and refetch when URLs change
  useEffect(() => {
    fetchSignedUrls();
  }, [fetchSignedUrls]);

  // Auto-refresh before expiry
  useEffect(() => {
    if (!expiresAt) return;

    const timeUntilRefresh =
      expiresAt.getTime() - Date.now() - refreshBuffer * 1000;

    if (timeUntilRefresh <= 0) {
      fetchSignedUrls();
      return;
    }

    const timer = setTimeout(() => {
      fetchSignedUrls();
    }, timeUntilRefresh);

    return () => clearTimeout(timer);
  }, [expiresAt, refreshBuffer, fetchSignedUrls]);

  return {
    signedUrls,
    isLoading,
    error,
    refreshUrls: fetchSignedUrls,
  };
}

// Helper to get signed URL or fallback to original
export function getSignedUrl(
  signedUrls: Map<string, string>,
  originalUrl: string
): string {
  return signedUrls.get(originalUrl) || originalUrl;
}
