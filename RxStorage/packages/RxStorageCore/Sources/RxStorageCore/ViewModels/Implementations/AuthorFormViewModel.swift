//
//  AuthorFormViewModel.swift
//  RxStorageCore
//
//  Author form view model implementation
//

import Foundation
import Observation

/// Author form view model implementation
@Observable
@MainActor
public final class AuthorFormViewModel: AuthorFormViewModelProtocol {
    // MARK: - Published Properties

    public let author: Author?

    // Form fields
    public var name = ""
    public var bio = ""

    // State
    public private(set) var isSubmitting = false
    public private(set) var error: Error?
    public private(set) var validationErrors: [String: String] = [:]

    // MARK: - Dependencies

    private let authorService: AuthorServiceProtocol
    private let eventViewModel: EventViewModel?

    // MARK: - Initialization

    public init(
        author: Author? = nil,
        authorService: AuthorServiceProtocol = AuthorService(),
        eventViewModel: EventViewModel? = nil
    ) {
        self.author = author
        self.authorService = authorService
        self.eventViewModel = eventViewModel

        // Populate form if editing
        if let author = author {
            populateForm(from: author)
        }
    }

    // MARK: - Public Methods

    public func validate() -> Bool {
        validationErrors.removeAll()

        // Validate name
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors["name"] = "Name is required"
        }

        return validationErrors.isEmpty
    }

    @discardableResult
    public func submit() async throws -> Author {
        guard validate() else {
            throw FormError.validationFailed
        }

        isSubmitting = true
        error = nil

        do {
            let result: Author
            if let existingAuthor = author {
                // Update - use UpdateAuthorRequest
                let updateRequest = UpdateAuthorRequest(
                    name: name,
                    bio: bio.isEmpty ? nil : bio
                )
                result = try await authorService.updateAuthor(id: existingAuthor.id, updateRequest)
                eventViewModel?.emit(.authorUpdated(id: result.id))
            } else {
                // Create - use NewAuthorRequest
                let createRequest = NewAuthorRequest(
                    name: name,
                    bio: bio.isEmpty ? nil : bio
                )
                result = try await authorService.createAuthor(createRequest)
                eventViewModel?.emit(.authorCreated(id: result.id))
            }

            isSubmitting = false
            return result
        } catch {
            self.error = error
            isSubmitting = false
            throw error
        }
    }

    // MARK: - Private Methods

    private func populateForm(from author: Author) {
        name = author.name
        bio = author.bio ?? ""
    }
}
