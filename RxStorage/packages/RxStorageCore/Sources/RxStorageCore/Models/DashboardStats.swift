//
//  DashboardStats.swift
//  RxStorageCore
//
//  Dashboard statistics model matching API schema
//

import Foundation

/// Recent item summary for dashboard
public struct RecentItem: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let visibility: StorageItem.Visibility
    public let categoryName: String?
    public let updatedAt: Date

    public init(
        id: Int,
        title: String,
        visibility: StorageItem.Visibility,
        categoryName: String?,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.visibility = visibility
        self.categoryName = categoryName
        self.updatedAt = updatedAt
    }
}

/// Dashboard statistics from /api/v1/dashboard/stats
public struct DashboardStats: Codable, Sendable {
    public let totalItems: Int
    public let publicItems: Int
    public let privateItems: Int
    public let totalCategories: Int
    public let totalLocations: Int
    public let totalAuthors: Int
    public let recentItems: [RecentItem]

    public init(
        totalItems: Int,
        publicItems: Int,
        privateItems: Int,
        totalCategories: Int,
        totalLocations: Int,
        totalAuthors: Int,
        recentItems: [RecentItem]
    ) {
        self.totalItems = totalItems
        self.publicItems = publicItems
        self.privateItems = privateItems
        self.totalCategories = totalCategories
        self.totalLocations = totalLocations
        self.totalAuthors = totalAuthors
        self.recentItems = recentItems
    }
}
