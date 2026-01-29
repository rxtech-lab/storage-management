//
//  Author.swift
//  RxStorageCore
//
//  Author model matching API schema
//

import Foundation

/// Author (creator/owner) of items
/// Note: When embedded in Item responses, only id and name are returned
public struct Author: Codable, Identifiable, Hashable {
    public let id: Int
    public let name: String
    public let bio: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: Int,
        name: String,
        bio: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.bio = bio
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Request body for creating a new author
public struct NewAuthorRequest: Codable {
    public let name: String
    public let bio: String?

    public init(name: String, bio: String? = nil) {
        self.name = name
        self.bio = bio
    }
}

/// Request body for updating an author
public typealias UpdateAuthorRequest = NewAuthorRequest
