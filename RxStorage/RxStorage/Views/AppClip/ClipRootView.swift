//
//  ClipRootView.swift
//  RxStorage
//
//  Root view for App Clips that parses URL and shows preview
//

import SwiftUI

/// Root view for App Clips
struct ClipRootView: View {
    @State private var itemId: Int?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let itemId = itemId {
                    ItemPreviewView(itemId: itemId)
                } else if let error = error {
                    ContentUnavailableView(
                        "Invalid URL",
                        systemImage: "link.badge.plus",
                        description: Text(error)
                    )
                } else {
                    ProgressView("Loading...")
                }
            }
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            handleUserActivity(userActivity)
        }
    }

    // MARK: - URL Handling

    private func handleUserActivity(_ userActivity: NSUserActivity) {
        guard let incomingURL = userActivity.webpageURL else {
            error = "No URL provided"
            return
        }

        // Parse URL to extract item ID
        // Expected format: https://yourdomain.com/preview/{id}
        // or: https://yourdomain.com/items/{id}
        let pathComponents = incomingURL.pathComponents

        if pathComponents.count >= 3 {
            // Try to find ID in path
            if let idString = pathComponents.last,
               let id = Int(idString) {
                self.itemId = id
                return
            }
        }

        // Try to parse from query parameters
        if let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems,
           let idString = queryItems.first(where: { $0.name == "id" })?.value,
           let id = Int(idString) {
            self.itemId = id
            return
        }

        error = "Could not extract item ID from URL: \(incomingURL.absoluteString)"
    }
}

#Preview {
    ClipRootView()
}
