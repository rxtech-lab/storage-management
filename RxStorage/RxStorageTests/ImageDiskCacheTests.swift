//
//  ImageDiskCacheTests.swift
//  RxStorageTests
//
//  Unit tests for ImageDiskCache
//

import Foundation
@testable import RxStorage
import Testing

@Suite("ImageDiskCache Tests")
struct ImageDiskCacheTests {
    /// Creates a temporary cache directory for testing.
    private func makeTempCache() -> ImageDiskCache {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImageDiskCacheTests-\(UUID().uuidString)", isDirectory: true)
        return ImageDiskCache(directory: dir)
    }

    // MARK: - Cache Key Generation

    @Test("Cache key strips query parameters for pre-signed S3 URLs")
    func cacheKeyStripsQuery() async throws {
        let cache = makeTempCache()
        let url1 = try #require(URL(string: "https://s3.example.com/bucket/image.png?X-Amz-Signature=abc123&X-Amz-Expires=3600"))
        let url2 = try #require(URL(string: "https://s3.example.com/bucket/image.png?X-Amz-Signature=def456&X-Amz-Expires=7200"))

        let key1 = await cache.cacheKey(for: url1)
        let key2 = await cache.cacheKey(for: url2)

        #expect(key1 == key2, "Same path with different query params should produce same cache key")
    }

    @Test("Cache key differs for different paths")
    func cacheKeyDiffersForDifferentPaths() async throws {
        let cache = makeTempCache()
        let url1 = try #require(URL(string: "https://s3.example.com/bucket/image1.png?sig=abc"))
        let url2 = try #require(URL(string: "https://s3.example.com/bucket/image2.png?sig=abc"))

        let key1 = await cache.cacheKey(for: url1)
        let key2 = await cache.cacheKey(for: url2)

        #expect(key1 != key2, "Different paths should produce different cache keys")
    }

    @Test("Cache key strips fragment")
    func cacheKeyStripsFragment() async throws {
        let cache = makeTempCache()
        let url1 = try #require(URL(string: "https://example.com/image.png#section1"))
        let url2 = try #require(URL(string: "https://example.com/image.png#section2"))

        let key1 = await cache.cacheKey(for: url1)
        let key2 = await cache.cacheKey(for: url2)

        #expect(key1 == key2)
    }

    @Test("Cache key is a valid hex string")
    func cacheKeyFormat() async throws {
        let cache = makeTempCache()
        let url = try #require(URL(string: "https://example.com/image.png"))
        let key = await cache.cacheKey(for: url)

        #expect(key.count == 64, "SHA256 hex string should be 64 characters")
        #expect(key.allSatisfy { $0.isHexDigit }, "Key should only contain hex characters")
    }

    // MARK: - Store and Retrieve

    @Test("Store and retrieve cached data")
    func storeAndRetrieve() async throws {
        let cache = makeTempCache()
        let url = try #require(URL(string: "https://example.com/test.png"))
        let data = Data("fake-image-data".utf8)

        await cache.store(data: data, for: url)
        let retrieved = await cache.cachedData(for: url)

        #expect(retrieved == data)
    }

    @Test("Returns nil for uncached URL")
    func missReturnsNil() async throws {
        let cache = makeTempCache()
        let url = try #require(URL(string: "https://example.com/nonexistent.png"))

        let result = await cache.cachedData(for: url)
        #expect(result == nil)
    }

    @Test("Pre-signed URL retrieves cache stored by different signature")
    func presignedUrlCacheHit() async throws {
        let cache = makeTempCache()
        let storeUrl = try #require(URL(string: "https://s3.example.com/bucket/photo.jpg?X-Amz-Signature=first&X-Amz-Date=20240101"))
        let retrieveUrl = try #require(URL(string: "https://s3.example.com/bucket/photo.jpg?X-Amz-Signature=second&X-Amz-Date=20240102"))
        let data = Data("s3-image-bytes".utf8)

        await cache.store(data: data, for: storeUrl)
        let retrieved = await cache.cachedData(for: retrieveUrl)

        #expect(retrieved == data, "Should hit cache despite different query params")
    }

    // MARK: - Clear

    @Test("Clear all removes cached data")
    func clearAll() async throws {
        let cache = makeTempCache()
        let url = try #require(URL(string: "https://example.com/clear-test.png"))
        let data = Data("to-be-cleared".utf8)

        await cache.store(data: data, for: url)
        #expect(await cache.cachedData(for: url) != nil)

        await cache.clearAll()
        #expect(await cache.cachedData(for: url) == nil)
    }

    // MARK: - Multiple entries

    @Test("Multiple URLs cached independently")
    func multipleEntries() async throws {
        let cache = makeTempCache()
        let url1 = try #require(URL(string: "https://example.com/a.png"))
        let url2 = try #require(URL(string: "https://example.com/b.png"))
        let data1 = Data("image-a".utf8)
        let data2 = Data("image-b".utf8)

        await cache.store(data: data1, for: url1)
        await cache.store(data: data2, for: url2)

        #expect(await cache.cachedData(for: url1) == data1)
        #expect(await cache.cachedData(for: url2) == data2)
    }

    // MARK: - Overwrite

    @Test("Storing same URL overwrites previous data")
    func overwrite() async throws {
        let cache = makeTempCache()
        let url = try #require(URL(string: "https://example.com/overwrite.png"))
        let data1 = Data("version-1".utf8)
        let data2 = Data("version-2".utf8)

        await cache.store(data: data1, for: url)
        await cache.store(data: data2, for: url)

        #expect(await cache.cachedData(for: url) == data2)
    }
}
