//
//  RootView.swift
//  RxStorage
//
//  Main navigation structure with NavigationSplitView
//

import SwiftUI
import RxStorageCore

/// Main navigation sections
enum NavigationSection: String, CaseIterable, Identifiable {
    case items = "Items"
    case categories = "Categories"
    case locations = "Locations"
    case authors = "Authors"
    case schemas = "Position Schemas"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .items: return "shippingbox"
        case .categories: return "folder"
        case .locations: return "mappin.circle"
        case .authors: return "person.circle"
        case .schemas: return "doc.text"
        }
    }
}

/// Root view with NavigationSplitView for iPad/iPhone adaptive layout
/// Uses three-column layout: Sidebar (sections) | Content (list) | Detail (selected item)
struct RootView: View {
    @State private var selectedSection: NavigationSection? = .items
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    // Lifted selection state for each section
    @State private var selectedItem: StorageItem?
    @State private var selectedCategory: RxStorageCore.Category?
    @State private var selectedAuthor: Author?
    @State private var selectedLocation: Location?
    @State private var selectedPositionSchema: PositionSchema?

    // Deep link state
    @State private var isLoadingDeepLink = false
    @State private var deepLinkError: Error?
    @State private var showDeepLinkError = false
    private let itemService = ItemService()

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Column 1: Sidebar (sections)
            sidebarContent
        } content: {
            // Column 2: List for selected section
            contentColumn
        } detail: {
            // Column 3: Detail for selected item
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        // Handle universal links (https://...)
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
            if let url = userActivity.webpageURL {
                Task {
                    await handleDeepLink(url)
                }
            }
        }
        // Handle custom URL scheme (rxstorage://...)
        .onOpenURL { url in
            Task {
                await handleDeepLink(url)
            }
        }
        .alert("Deep Link Error", isPresented: $showDeepLinkError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = deepLinkError {
                Text(error.localizedDescription)
            }
        }
        .overlay {
            if isLoadingDeepLink {
                ZStack {
                    Color.black.opacity(0.3)
                    ProgressView("Loading item...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(NavigationSection.allCases, selection: $selectedSection) { section in
            NavigationLink(value: section) {
                Label(section.rawValue, systemImage: section.systemImage)
            }
        }
        .navigationTitle("RxStorage")
        .listStyle(.sidebar)
    }

    // MARK: - Content Column (Lists)

    @ViewBuilder
    private var contentColumn: some View {
        if let section = selectedSection {
            switch section {
            case .items:
                ItemListView(selectedItem: $selectedItem)
            case .categories:
                CategoryListView(selectedCategory: $selectedCategory)
            case .locations:
                LocationListView(selectedLocation: $selectedLocation)
            case .authors:
                AuthorListView(selectedAuthor: $selectedAuthor)
            case .schemas:
                PositionSchemaListView(selectedSchema: $selectedPositionSchema)
            }
        } else {
            ContentUnavailableView(
                "Select a section",
                systemImage: "sidebar.left",
                description: Text("Choose a section from the sidebar")
            )
        }
    }

    // MARK: - Detail Column

    @ViewBuilder
    private var detailColumn: some View {
        switch selectedSection {
        case .items:
            NavigationStack {
                Group {
                    if let item = selectedItem {
                        ItemDetailView(itemId: item.id)
                    } else {
                        ContentUnavailableView(
                            "Select an item",
                            systemImage: "shippingbox",
                            description: Text("Choose an item from the list to view details")
                        )
                    }
                }
                .navigationDestination(for: StorageItem.self) { child in
                    ItemDetailView(itemId: child.id)
                }
            }
        case .categories:
            if let category = selectedCategory {
                CategoryDetailView(categoryId: category.id)
            } else {
                ContentUnavailableView(
                    "Select a category",
                    systemImage: "folder",
                    description: Text("Choose a category from the list to view details")
                )
            }
        case .locations:
            if let location = selectedLocation {
                LocationDetailView(locationId: location.id)
            } else {
                ContentUnavailableView(
                    "Select a location",
                    systemImage: "mappin.circle",
                    description: Text("Choose a location from the list to view details")
                )
            }
        case .authors:
            if let author = selectedAuthor {
                AuthorDetailView(authorId: author.id)
            } else {
                ContentUnavailableView(
                    "Select an author",
                    systemImage: "person.circle",
                    description: Text("Choose an author from the list to view details")
                )
            }
        case .schemas:
            if let schema = selectedPositionSchema {
                PositionSchemaDetailView(schemaId: schema.id)
            } else {
                ContentUnavailableView(
                    "Select a schema",
                    systemImage: "doc.text",
                    description: Text("Choose a schema from the list to view details")
                )
            }
        case .none:
            ContentUnavailableView(
                "Select a section",
                systemImage: "sidebar.left",
                description: Text("Choose a section from the sidebar")
            )
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) async {
        // Ensure we're on the items section
        selectedSection = .items

        isLoadingDeepLink = true
        defer { isLoadingDeepLink = false }

        do {
            let item = try await itemService.fetchItemFromURL(url)
            selectedItem = item
        } catch {
            deepLinkError = error
            showDeepLinkError = true
        }
    }
}

#Preview {
    RootView()
}
