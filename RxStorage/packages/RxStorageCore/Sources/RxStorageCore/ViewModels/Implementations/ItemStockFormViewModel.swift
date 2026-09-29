//
//  ItemStockFormViewModel.swift
//  RxStorageCore
//
//  Edits a stock placement's location, note, images, and positions
//

import Foundation
import Observation
import OpenAPIRuntime
import OSLog

private let logger = Logger(subsystem: "com.rxlab.rxstorage", category: "ItemStockFormViewModel")

@Observable
@MainActor
public final class ItemStockFormViewModel {
    // MARK: - Properties

    public let stock: ItemStock

    public var selectedLocationId: String?
    public var selectedLocationTitle: String?
    public var note: String
    public private(set) var existingImages: [ImageReference]
    public private(set) var pendingUploads: [PendingUpload] = []
    /// Saved positions that are kept on submit
    public private(set) var positions: [PositionRef]
    public private(set) var pendingPositions: [PendingPosition] = []
    public var positionSchemas: [PositionSchema] = []

    public private(set) var isUploading = false
    public private(set) var isSubmitting = false

    private let stockService: ItemStockServiceProtocol
    private let positionSchemaService: PositionSchemaServiceProtocol
    private let uploadManager: UploadManager

    // MARK: - Initialization

    public init(
        stock: ItemStock,
        stockService: ItemStockServiceProtocol = ItemStockService(),
        positionSchemaService: PositionSchemaServiceProtocol = PositionSchemaService(),
        uploadManager: UploadManager = .shared
    ) {
        self.stock = stock
        self.stockService = stockService
        self.positionSchemaService = positionSchemaService
        self.uploadManager = uploadManager
        selectedLocationId = stock.locationId
        selectedLocationTitle = stock.location?.value1.title
        note = stock.note ?? ""
        existingImages = stock.images.map { ImageReference(url: $0.url, fileId: $0.id) }
        positions = stock.positions
    }

    // MARK: - Reference Data

    public func loadReferenceData() async {
        do {
            positionSchemas = try await positionSchemaService.fetchPositionSchemas(filters: nil)
        } catch {
            logger.error("Failed to load position schemas: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func schemaName(for positionSchemaId: String) -> String {
        positionSchemas.first { $0.id == positionSchemaId }?.name ?? "Position"
    }

    // MARK: - Positions

    public func addPendingPosition(schema: PositionSchema, data: [String: AnyCodable]) {
        pendingPositions.append(PendingPosition(positionSchemaId: schema.id, schema: schema, data: data))
    }

    public func removePendingPosition(id: UUID) {
        pendingPositions.removeAll { $0.id == id }
    }

    public func removePosition(id: String) {
        positions.removeAll { $0.id == id }
    }

    // MARK: - Images

    public func addImage(from localURL: URL) {
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? Int64) ?? 0
        pendingUploads.append(PendingUpload(
            localURL: localURL,
            filename: localURL.lastPathComponent,
            contentType: MIMEType.from(url: localURL),
            fileSize: fileSize
        ))
    }

    public func uploadPendingImages() async {
        isUploading = true
        defer { isUploading = false }

        for index in pendingUploads.indices where pendingUploads[index].status == .pending {
            pendingUploads[index].status = .uploading
            do {
                let result = try await uploadManager.upload(
                    file: pendingUploads[index].localURL,
                    onProgress: { [weak self] uploaded, total in
                        Task { @MainActor in
                            guard let self, index < self.pendingUploads.count else { return }
                            self.pendingUploads[index].progress = Double(uploaded) / Double(max(total, 1))
                        }
                    }
                )
                pendingUploads[index].fileId = result.fileId
                pendingUploads[index].publicUrl = result.publicUrl
                pendingUploads[index].progress = 1.0
                pendingUploads[index].status = .completed
            } catch {
                pendingUploads[index].status = .failed(error.localizedDescription)
            }
        }
    }

    public func removePendingUpload(id: UUID) {
        pendingUploads.removeAll { $0.id == id }
    }

    public func removeSavedImage(at index: Int) {
        guard existingImages.indices.contains(index) else { return }
        existingImages.remove(at: index)
    }

    public var hasFailedUploads: Bool {
        pendingUploads.contains { $0.status.isFailed }
    }

    // MARK: - Submit

    /// Build the update request. Positions replace the placement's saved positions.
    public func makeRequest() -> UpdateItemStockRequest {
        let keptPositions = positions.map { position in
            Components.Schemas.NewPositionDataSchema(
                positionSchemaId: position.positionSchemaId,
                data: .init(additionalProperties: position.data.additionalProperties)
            )
        }
        let images = existingImages.map(\.fileReference) + pendingUploads.compactMap(\.fileReference)
        return UpdateItemStockRequest(
            // Empty string clears the location (nil fields are dropped from the request body)
            locationId: selectedLocationId ?? "",
            images: images,
            note: note,
            positions: keptPositions + pendingPositions.map(\.asNewPositionData)
        )
    }

    @discardableResult
    public func submit() async throws -> ItemStock {
        if pendingUploads.contains(where: { $0.status == .pending }) {
            await uploadPendingImages()
        }
        if hasFailedUploads {
            throw ItemStockFormError.uploadFailed
        }

        isSubmitting = true
        defer { isSubmitting = false }
        return try await stockService.updateStock(id: stock.id, makeRequest())
    }
}

public enum ItemStockFormError: LocalizedError {
    case uploadFailed

    public var errorDescription: String? {
        switch self {
        case .uploadFailed:
            return "Some images failed to upload. Remove them or try again."
        }
    }
}
