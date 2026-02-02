//
//  NavigationManager.swift
//  RxStorage
//
//  Centralized navigation state manager for adaptive navigation
//

import Observation
import RxStorageCore
import SwiftUI

/// Main tabs in TabView (iPhone) and sections in Sidebar (iPad)
enum AppTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case items = "Items"
    case management = "Management"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: return "chart.bar"
        case .items: return "shippingbox"
        case .management: return "folder"
        case .settings: return "gearshape"
        }
    }
}

/// Sub-sections within the Management tab/section
enum ManagementSection: String, CaseIterable, Identifiable {
    case categories = "Categories"
    case locations = "Locations"
    case authors = "Authors"
    case positionSchemas = "Position Schemas"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .categories: return "folder"
        case .locations: return "mappin.circle"
        case .authors: return "person.circle"
        case .positionSchemas: return "doc.text"
        }
    }
}

/// Centralized navigation state manager
@Observable
@MainActor
final class NavigationManager {
    // MARK: - Tab/Section Selection

    /// Currently selected tab (TabView) or section (Sidebar)
    var selectedTab: AppTab = .dashboard

    /// Selected sub-section within Management
    var selectedManagementSection: ManagementSection = .categories

    // MARK: - Detail Selection State

    /// Selected item for detail view
    var selectedItem: StorageItem?

    /// Selected category for detail view
    var selectedCategory: RxStorageCore.Category?

    /// Selected location for detail view
    var selectedLocation: Location?

    /// Selected author for detail view
    var selectedAuthor: Author?

    /// Selected position schema for detail view
    var selectedPositionSchema: PositionSchema?

    // MARK: - Navigation Paths (for NavigationStack in TabView)

    /// Navigation path for Items tab
    var itemsNavigationPath = NavigationPath()

    /// Navigation path for Management tab
    var managementNavigationPath = NavigationPath()

    /// Navigation path for Dashboard tab
    var dashboardNavigationPath = NavigationPath()

    // MARK: - Deep Link State

    var isLoadingDeepLink = false
    var deepLinkError: Error?
    var showDeepLinkError = false

    // MARK: - Column Visibility (iPad)

    var columnVisibility: NavigationSplitViewVisibility = .automatic

    // MARK: - Services

    private let itemService = ItemService()

    // MARK: - Navigation Methods

    /// Navigate to a specific item
    func navigateToItem(_ item: StorageItem) {
        selectedTab = .items
        selectedItem = item
        // For TabView, push onto navigation stack
        itemsNavigationPath.append(item)
    }

    /// Navigate to an item by its ID (fetches the full item first)
    func navigateToItemById(_ id: Int) async {
        selectedTab = .items
        isLoadingDeepLink = true
        defer { isLoadingDeepLink = false }

        do {
            let itemDetail = try await itemService.fetchItem(id: id)
            let item = itemDetail.toStorageItem()
            selectedItem = item
            itemsNavigationPath.append(item)
        } catch {
            deepLinkError = error
            showDeepLinkError = true
        }
    }

    /// Navigate to items tab
    func navigateToItems() {
        selectedTab = .items
    }

    /// Navigate to a specific management section
    func navigateToManagement(_ section: ManagementSection) {
        selectedTab = .management
        selectedManagementSection = section
    }

    /// Clear all detail selections
    func clearSelections() {
        selectedItem = nil
        selectedCategory = nil
        selectedLocation = nil
        selectedAuthor = nil
        selectedPositionSchema = nil
    }

    /// Clear navigation paths
    func clearNavigationPaths() {
        itemsNavigationPath = NavigationPath()
        managementNavigationPath = NavigationPath()
        dashboardNavigationPath = NavigationPath()
    }

    // MARK: - Deep Link Handling

    /// Handle deep link URL
    func handleDeepLink(_ url: URL) async {
        // Extract item ID from URL path (e.g., /preview/123)
        guard let itemIdString = url.pathComponents.last,
              let itemId = Int(itemIdString) else {
            deepLinkError = APIError.unsupportedQRCode(url.absoluteString)
            showDeepLinkError = true
            return
        }

        // Navigate to the item by ID
        await navigateToItemById(itemId)
    }
}
