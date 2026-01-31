//
//  TabBarView.swift
//  RxStorage
//
//  TabView implementation for iPhone (compact size class)
//

import RxStorageCore
import SwiftUI

/// TabView with 4 tabs for iPhone navigation
struct TabBarView: View {
    @Environment(NavigationManager.self) private var navigationManager

    var body: some View {
        @Bindable var nav = navigationManager

        TabView(selection: $nav.selectedTab) {
            // Dashboard Tab
            NavigationStack(path: $nav.dashboardNavigationPath) {
                DashboardView()
                    .navigationDestination(for: StorageItem.self) { item in
                        ItemDetailView(itemId: item.id)
                    }
            }
            .tabItem {
                Label(AppTab.dashboard.rawValue, systemImage: AppTab.dashboard.systemImage)
            }
            .tag(AppTab.dashboard)

            // Items Tab
            NavigationStack(path: $nav.itemsNavigationPath) {
                ItemListView()
                    .navigationDestination(for: StorageItem.self) { item in
                        ItemDetailView(itemId: item.id)
                    }
            }
            .tabItem {
                Label(AppTab.items.rawValue, systemImage: AppTab.items.systemImage)
            }
            .tag(AppTab.items)

            // Management Tab
            NavigationStack(path: $nav.managementNavigationPath) {
                ManagementView()
                    .navigationDestination(for: ManagementSection.self) { section in
                        ManagementSectionListView(section: section)
                    }
                    .navigationDestination(for: RxStorageCore.Category.self) { category in
                        CategoryDetailView(categoryId: category.id)
                    }
                    .navigationDestination(for: Location.self) { location in
                        LocationDetailView(locationId: location.id)
                    }
                    .navigationDestination(for: Author.self) { author in
                        AuthorDetailView(authorId: author.id)
                    }
                    .navigationDestination(for: PositionSchema.self) { schema in
                        PositionSchemaDetailView(schemaId: schema.id)
                    }
            }
            .tabItem {
                Label(AppTab.management.rawValue, systemImage: AppTab.management.systemImage)
            }
            .tag(AppTab.management)

            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(AppTab.settings.rawValue, systemImage: AppTab.settings.systemImage)
            }
            .tag(AppTab.settings)
        }
    }
}

#Preview {
    TabBarView()
        .environment(NavigationManager())
}
