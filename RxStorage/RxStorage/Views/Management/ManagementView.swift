//
//  ManagementView.swift
//  RxStorage
//
//  Management section view for iPhone TabView navigation
//

import RxStorageCore
import SwiftUI

/// Management view showing list of management sections (for iPhone TabView)
struct ManagementView: View {
    var body: some View {
        List {
            Section {
                ForEach(ManagementSection.allCases) { section in
                    NavigationLink(value: section) {
                        Label(section.rawValue, systemImage: section.systemImage)
                    }
                }
            } header: {
                Text("Manage your storage data")
            } footer: {
                Text("Select a section to view and manage its items")
            }
        }
        .navigationTitle("Management")
    }
}

/// List view for a specific management section (pushed from ManagementView)
struct ManagementSectionListView: View {
    let section: ManagementSection

    var body: some View {
        switch section {
        case .categories:
            CategoryListView()
        case .locations:
            LocationListView()
        case .authors:
            AuthorListView()
        case .positionSchemas:
            PositionSchemaListView()
        }
    }
}

#Preview {
    NavigationStack {
        ManagementView()
    }
    .environment(NavigationManager())
}
