//
//  CachedAsyncImage.swift
//  RxStorage
//
//  Disk-cached replacement for AsyncImage. Caches images for 24 hours.
//  Handles pre-signed S3 URLs by stripping query parameters for cache keys.
//

import CryptoKit
import SwiftUI

#if canImport(UIKit)
    import UIKit

    private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
    import AppKit

    private typealias PlatformImage = NSImage
#endif

// MARK: - Image Disk Cache

actor ImageDiskCache {
    static let shared = ImageDiskCache()

    private let cacheDirectory: URL
    private let cacheDuration: TimeInterval = 24 * 60 * 60 // 24 hours

    init(directory: URL? = nil) {
        if let directory {
            cacheDirectory = directory
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            cacheDirectory = caches.appendingPathComponent("CachedImages", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Generate a cache key by hashing the URL path without query parameters.
    /// This ensures pre-signed S3 URLs with different signatures map to the same cache entry.
    func cacheKey(for url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        let normalized = components?.string ?? url.absoluteString
        let hash = SHA256.hash(data: Data(normalized.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Returns the cached image data if it exists and hasn't expired.
    func cachedData(for url: URL) -> Data? {
        let key = cacheKey(for: url)
        let fileURL = cacheDirectory.appendingPathComponent(key)
        let metaURL = cacheDirectory.appendingPathComponent(key + ".meta")

        guard FileManager.default.fileExists(atPath: fileURL.path),
              FileManager.default.fileExists(atPath: metaURL.path),
              let metaData = try? Data(contentsOf: metaURL),
              let timestamp = String(data: metaData, encoding: .utf8),
              let savedDate = TimeInterval(timestamp)
        else {
            return nil
        }

        if Date().timeIntervalSince1970 - savedDate > cacheDuration {
            // Expired — clean up
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: metaURL)
            return nil
        }

        return try? Data(contentsOf: fileURL)
    }

    /// Store image data to disk cache.
    func store(data: Data, for url: URL) {
        let key = cacheKey(for: url)
        let fileURL = cacheDirectory.appendingPathComponent(key)
        let metaURL = cacheDirectory.appendingPathComponent(key + ".meta")

        try? data.write(to: fileURL)
        let timestamp = String(Date().timeIntervalSince1970)
        try? timestamp.data(using: .utf8)?.write(to: metaURL)
    }

    /// Remove all cached images.
    func clearAll() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - Cached Async Image View

struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        content(phase)
            .task(id: url) {
                await loadImage()
            }
    }

    private static func makeImage(from data: Data) -> Image? {
        #if canImport(UIKit)
            guard let platformImage = PlatformImage(data: data) else { return nil }
            return Image(uiImage: platformImage)
        #elseif canImport(AppKit)
            guard let platformImage = PlatformImage(data: data) else { return nil }
            return Image(nsImage: platformImage)
        #endif
    }

    private func loadImage() async {
        guard let url else {
            phase = .empty
            return
        }

        // Check disk cache first
        if let cachedData = await ImageDiskCache.shared.cachedData(for: url),
           let image = Self.makeImage(from: cachedData)
        {
            phase = .success(image)
            return
        }

        // Download from network
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = Self.makeImage(from: data) else {
                phase = .failure(CachedImageError.invalidData)
                return
            }

            // Cache to disk
            await ImageDiskCache.shared.store(data: data, for: url)

            phase = .success(image)
        } catch {
            phase = .failure(error)
        }
    }
}

enum CachedImageError: Error {
    case invalidData
}
