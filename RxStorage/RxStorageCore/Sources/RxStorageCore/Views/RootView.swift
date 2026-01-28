//
//  RootView.swift
//  RxStorageCore
//
//  Main navigation structure with NavigationSplitView
//

import SwiftUI

/// Main navigation sections
public enum NavigationSection: String, CaseIterable, Identifiable {
    case items = "Items"
    case categories = "Categories"
    case locations = "Locations"
    case authors = "Authors"
    case schemas = "Position Schemas"

    public var id: String { rawValue }

    public var systemImage: String {
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
public struct RootView: View {
    @State private var selectedSection: NavigationSection? = .items
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            sidebarContent
        } detail: {
            // Detail/Content
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
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

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        if let section = selectedSection {
            switch section {
            case .items:
                ItemListView()
            case .categories:
                CategoryListView()
            case .locations:
                LocationListView()
            case .authors:
                AuthorListView()
            case .schemas:
                PositionSchemaListView()
            }
        } else {
            ContentUnavailableView(
                "Select a section",
                systemImage: "sidebar.left",
                description: Text("Choose a section from the sidebar to get started")
            )
        }
    }
}

#Preview {
    RootView()
}
