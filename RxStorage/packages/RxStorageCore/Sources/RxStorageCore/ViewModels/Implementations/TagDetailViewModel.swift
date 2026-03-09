//
//  TagDetailViewModel.swift
//  RxStorage
//
//  Tag detail view model for displaying tag details
//

import Foundation
import Observation

/// Tag detail view model
@Observable
@MainActor
public final class TagDetailViewModel {
    // MARK: - Properties

    public private(set) var tag: Tag?
    public private(set) var isLoading = false
    public private(set) var error: Error?

    // MARK: - Items Properties

    public private(set) var items: [StorageItem] = []
    public private(set) var totalItems: Int = 0

    // MARK: - Dependencies

    private let tagService: TagServiceProtocol

    // MARK: - Initialization

    public init(tagService: TagServiceProtocol? = nil) {
        self.tagService = tagService ?? TagService()
    }

    // MARK: - Public Methods

    public func fetchTag(id: String) async {
        isLoading = true
        error = nil

        do {
            let detail = try await tagService.fetchTagDetail(id: id)
            tag = Tag(id: detail.id, userId: detail.userId, title: detail.title, color: detail.color, createdAt: detail.createdAt, updatedAt: detail.updatedAt)
            items = detail.items
            totalItems = detail.totalItems
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    func refresh() async {
        guard let tagId = tag?.id else { return }
        await fetchTag(id: tagId)
    }

    func clearError() {
        error = nil
    }
}
