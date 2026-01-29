//
//  ItemPreviewView.swift
//  RxStorage
//
//  Read-only item preview view for App Clips
//

import SwiftUI
import RxStorageCore

/// Item preview view (read-only) for App Clips
struct ItemPreviewView: View {
    let itemId: Int

    @State private var viewModel = ItemPreviewViewModel()
    @State private var showingAuthSheet = false

    init(itemId: Int) {
        self.itemId = itemId
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
            } else if let preview = viewModel.preview {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header with badge
                        previewHeader(preview)

                        Divider()

                        // Details
                        previewDetails(preview)

                        // App Store prompt
                        Divider()
                        appStorePrompt
                    }
                    .padding()
                }
            } else if let error = viewModel.error {
                errorView(error)
            }
        }
        .navigationTitle(viewModel.preview?.title ?? "Preview")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchPreview(id: itemId)
        }
        .sheet(isPresented: $showingAuthSheet) {
            AuthenticationView()
        }
    }

    // MARK: - Preview Header

    @ViewBuilder
    private func previewHeader(_ preview: ItemPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preview.title)
                .font(.title2)
                .fontWeight(.bold)

            if let description = preview.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if preview.visibility == .public {
                    Label("Public", systemImage: "globe")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .cornerRadius(4)
                } else {
                    Label("Private", systemImage: "lock.fill")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .cornerRadius(4)
                }
            }
        }
    }

    // MARK: - Preview Details

    @ViewBuilder
    private func previewDetails(_ preview: ItemPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let category = preview.category {
                PreviewDetailRow(label: "Category", value: category.name, icon: "folder")
            }

            if let location = preview.location {
                PreviewDetailRow(label: "Location", value: location.title, icon: "mappin")
            }

            if let author = preview.author {
                PreviewDetailRow(label: "Author", value: author.name, icon: "person")
            }

            if let price = preview.price {
                PreviewDetailRow(label: "Price", value: String(format: "%.2f", price), icon: "dollarsign.circle")
            }

            if !preview.images.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Images", systemImage: "photo")
                        .font(.headline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(preview.images, id: \.self) { imageURL in
                                AsyncImage(url: URL(string: imageURL)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            if viewModel.requiresAuthentication {
                ContentUnavailableView(
                    "Authentication Required",
                    systemImage: "lock.fill",
                    description: Text("This item is private. Sign in to view it.")
                )

                Button {
                    showingAuthSheet = true
                } label: {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            } else {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            }
        }
    }

    // MARK: - App Store Prompt

    private var appStorePrompt: some View {
        VStack(spacing: 12) {
            Text("Get the Full App")
                .font(.headline)

            Text("Download RxStorage for full access to all features including editing, creating items, and more.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                // Open App Store
                // Note: Replace with actual App Store URL
                if let url = URL(string: "https://apps.apple.com/app/rxstorage/id123456789") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Download on the App Store", systemImage: "arrow.down.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Preview detail row component
struct PreviewDetailRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Label(label, systemImage: icon)
                .font(.headline)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        ItemPreviewView(itemId: 1)
    }
}
