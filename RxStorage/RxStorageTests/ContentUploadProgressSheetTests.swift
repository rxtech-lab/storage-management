import Foundation
@testable import RxStorage
@testable import RxStorageCore
import SwiftUI
import Testing
import ViewInspector

@Suite("ContentUploadProgressSheet UI Tests")
@MainActor
struct ContentUploadProgressSheetTests {
    // MARK: - Idle State Button Tests

    @Test("Idle state shows Cancel and Upload buttons, not Done or New Upload")
    func idleStateShowsCorrectButtons() throws {
        let uploadCenter = ContentUploadCenterViewModel.previewIdle()
        let sut = ContentUploadProgressSheet(
            itemId: "preview-item",
            itemTitle: "Sample Item",
            onClose: {},
            onUploadFiles: {},
            onUploadFolder: {},
            uploadCenter: uploadCenter
        )

        let inspection = try sut.inspect()

        // Should find Cancel button
        let cancelButton = try? inspection.find(viewWithAccessibilityIdentifier: "upload-cancel-button")
        #expect(cancelButton != nil, "Cancel button should be visible in idle state")

        // Should find Upload button
        let uploadButton = try? inspection.find(viewWithAccessibilityIdentifier: "upload-start-button")
        #expect(uploadButton != nil, "Upload button should be visible in idle state")

        // Should NOT find Done button
        let doneButton = try? inspection.find(viewWithAccessibilityIdentifier: "upload-done-button")
        #expect(doneButton == nil, "Done button should NOT be visible in idle state")

        // Should NOT find New Upload menu
        let newUploadMenu = try? inspection.find(viewWithAccessibilityIdentifier: "new-upload-menu")
        #expect(newUploadMenu == nil, "New Upload menu should NOT be visible in idle state")
    }

    // MARK: - Running State Button Tests

    @Test("Running state shows Close button, not Cancel, Upload, Done, or New Upload")
    func runningStateShowsCorrectButtons() throws {
        let uploadCenter = ContentUploadCenterViewModel.previewRunning()
        let sut = ContentUploadProgressSheet(
            itemId: "preview-item",
            itemTitle: "Sample Item",
            onClose: {},
            onUploadFiles: {},
            onUploadFolder: {},
            uploadCenter: uploadCenter
        )

        let inspection = try sut.inspect()

        // Should find Close button
        let closeButton = try? inspection.find(viewWithAccessibilityIdentifier: "upload-close-button")
        #expect(closeButton != nil, "Close button should be visible in running state")

        // Should NOT find Cancel button
        let cancelButton = try? inspection.find(viewWithAccessibilityIdentifier: "upload-cancel-button")
        #expect(cancelButton == nil, "Cancel button should NOT be visible in running state")

        // Should NOT find Upload button
        let uploadButton = try? inspection.find(viewWithAccessibilityIdentifier: "upload-start-button")
        #expect(uploadButton == nil, "Upload button should NOT be visible in running state")

        // Should NOT find Done button
        let doneButton = try? inspection.find(viewWithAccessibilityIdentifier: "upload-done-button")
        #expect(doneButton == nil, "Done button should NOT be visible in running state")

        // Should NOT find New Upload menu
        let newUploadMenu = try? inspection.find(viewWithAccessibilityIdentifier: "new-upload-menu")
        #expect(newUploadMenu == nil, "New Upload menu should NOT be visible in running state")
    }

    // MARK: - Completed State Button Tests

    @Test("Completed state shows Done and New Upload, not Cancel or Upload")
    func completedStateShowsCorrectButtons() throws {
        let uploadCenter = ContentUploadCenterViewModel.previewCompleted()
        let sut = ContentUploadProgressSheet(
            itemId: "preview-item",
            itemTitle: "Sample Item",
            onClose: {},
            onUploadFiles: {},
            onUploadFolder: {},
            uploadCenter: uploadCenter
        )

        let inspection = try sut.inspect()

        // Should NOT find Cancel button
        let cancelButton = try? inspection.find(viewWithAccessibilityIdentifier: "upload-cancel-button")
        #expect(cancelButton == nil, "Cancel button should NOT be visible in completed state")

        // Should NOT find Upload button
        let uploadButton = try? inspection.find(viewWithAccessibilityIdentifier: "upload-start-button")
        #expect(uploadButton == nil, "Upload button should NOT be visible in completed state")

        // Should find Done button
        let doneButton = try? inspection.find(viewWithAccessibilityIdentifier: "upload-done-button")
        #expect(doneButton != nil, "Done button should be visible in completed state")

        // Should find New Upload menu
        let newUploadMenu = try? inspection.find(viewWithAccessibilityIdentifier: "new-upload-menu")
        #expect(newUploadMenu != nil, "New Upload menu should be visible in completed state")
    }

    // MARK: - No Session State Button Tests

    @Test("No session state shows Cancel button only")
    func noSessionStateShowsCorrectButtons() throws {
        let uploadCenter = ContentUploadCenterViewModel()
        let sut = ContentUploadProgressSheet(
            itemId: "nonexistent-item",
            itemTitle: "Sample Item",
            onClose: {},
            onUploadFiles: {},
            onUploadFolder: {},
            uploadCenter: uploadCenter
        )

        let inspection = try sut.inspect()

        // Should find Cancel button
        let cancelButton = try? inspection.find(viewWithAccessibilityIdentifier: "upload-cancel-button")
        #expect(cancelButton != nil, "Cancel button should be visible when no session")

        // Should NOT find Upload button
        let uploadButton = try? inspection.find(viewWithAccessibilityIdentifier: "upload-start-button")
        #expect(uploadButton == nil, "Upload button should NOT be visible when no session")

        // Should NOT find Done button
        let doneButton = try? inspection.find(viewWithAccessibilityIdentifier: "upload-done-button")
        #expect(doneButton == nil, "Done button should NOT be visible when no session")

        // Should NOT find New Upload menu
        let newUploadMenu = try? inspection.find(viewWithAccessibilityIdentifier: "new-upload-menu")
        #expect(newUploadMenu == nil, "New Upload menu should NOT be visible when no session")
    }
}
