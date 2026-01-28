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

    // MARK: - Initialization

    public init(
        author: Author? = nil,
        authorService: AuthorServiceProtocol = AuthorService()
    ) {
        self.author = author
        self.authorService = authorService

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

    public func submit() async throws {
        guard validate() else {
            throw FormError.validationFailed
        }

        isSubmitting = true
        error = nil

        do {
            let request = NewAuthorRequest(
                name: name,
                bio: bio.isEmpty ? nil : bio
            )

            if let existingAuthor = author {
                // Update
                _ = try await authorService.updateAuthor(id: existingAuthor.id, request)
            } else {
                // Create
                _ = try await authorService.createAuthor(request)
            }

            isSubmitting = false
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
