//
//  ItemDetailViewModelProtocol.swift
//  RxStorageCore
//
//  Protocol for item detail view model
//

import Foundation

/// Protocol for item detail view model operations
@MainActor
public protocol ItemDetailViewModelProtocol: AnyObject, Observable {
    /// Current item
    var item: StorageItem? { get }

    /// Child items (if hierarchical)
    var children: [StorageItem] { get }

    /// Loading state
    var isLoading: Bool { get }

    /// Error state
    var error: Error? { get }

    /// QR code data
    var qrCodeData: QRCodeData? { get }

    /// Whether QR code is being generated
    var isGeneratingQR: Bool { get }

    /// Fetch item details
    func fetchItem(id: Int) async

    /// Fetch child items
    func fetchChildren() async

    /// Generate QR code
    func generateQRCode() async

    /// Refresh all data
    func refresh() async
}
