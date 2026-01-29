//
//  Category.swift
//  RxStorageCore
//
//  Category model matching API schema
//

import Foundation

/// Category for organizing items
/// Note: When embedded in Item responses, only id and name are returned
public struct Category: Codable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let description: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: Int,
        name: String,
        description: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Request body for creating a new category
public struct NewCategoryRequest: Codable {
    public let name: String
    public let description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

/// Request body for updating a category
public typealias UpdateCategoryRequest = NewCategoryRequest
