//
//  SidebarNavigationView.swift
//  RxStorage
//
//  NavigationSplitView implementation for iPad (regular size class)
//

import RxStorageCore
import SwiftUI

/// NavigationSplitView with three columns for iPad
struct SidebarNavigationView: View {
    @Environment(NavigationManager.self) private var navigationManager

    #if os(iOS)
        @State private var showQrCodeScanner = false
        @State private var isLoadingFromQR = false
        private let itemService = ItemService()
        private let qrCodeService = QrCodeService()
    #endif

    var body: some View {
        @Bindable var nav = navigationManager

        NavigationSplitView(columnVisibility: $nav.columnVisibility) {
            // Column 1: Sidebar
            #if os(iOS)
                SidebarContent(showQrCodeScanner: $showQrCodeScanner)
            #else
                SidebarContent()
            #endif
        } content: {
            // Column 2: List
            ContentColumn()
            #if os(macOS)
                .frame(minWidth: 400)
            #endif
        } detail: {
            // Column 3: Detail
            DetailColumn()
            #if os(macOS)
                .frame(minWidth: 400)
            #endif
        }
        .navigationSplitViewStyle(.balanced)
        #if os(iOS)
            .sheet(isPresented: $showQrCodeScanner) {
                NavigationStack {
                    QRCodeScannerView { code in
                        showQrCodeScanner = false
                        Task {
                            await handleScannedQRCode(code)
                        }
                    }
                }
            }
            .overlay {
                if isLoadingFromQR {
                    LoadingOverlay(title: "Loading item from QR code...")
                }
            }
        #endif
    }

    #if os(iOS)
        private func handleScannedQRCode(_ code: String) async {
            isLoadingFromQR = true
            defer { isLoadingFromQR = false }

            do {
                let scanResponse = try await qrCodeService.scanQrCode(qrcontent: code)
                let itemDetail = try await itemService.fetchItemUsingUrl(url: scanResponse.url)
                let item = itemDetail.toStorageItem()
                navigationManager.navigateToItem(item)
            } catch {
                navigationManager.deepLinkError = error
                navigationManager.showDeepLinkError = true
            }
        }
    #endif
}

// MARK: - Sidebar Content

/// Sidebar with navigation sections
struct SidebarContent: View {
    @Environment(NavigationManager.self) private var navigationManager

    #if os(iOS)
        @Binding var showQrCodeScanner: Bool

        init(showQrCodeScanner: Binding<Bool>) {
            _showQrCodeScanner = showQrCodeScanner
        }
    #else
        init() {}
    #endif

    var body: some View {
        List {
            mainSection
            managementSection
            settingsSection
        }
        .navigationTitle("RxStorage")
        .listStyle(.sidebar)
        #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showQrCodeScanner = true
                    } label: {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                    }
                    .accessibilityIdentifier("qr-scanner-button")
                }
            }
        #endif
    }

    private var mainSection: some View {
        Section {
            SidebarButton(tab: .dashboard)
            SidebarButton(tab: .items)
        }
    }

    private var managementSection: some View {
        Section("Manage") {
            ForEach(ManagementSection.allCases) { section in
                ManagementSectionButton(section: section)
            }
        }
    }

    private var settingsSection: some View {
        Section {
            SidebarButton(tab: .settings)
        }
    }
}

/// Sidebar button for main tabs
struct SidebarButton: View {
    let tab: AppTab
    @Environment(NavigationManager.self) private var navigationManager

    var body: some View {
        Button {
            navigationManager.selectedTab = tab
        } label: {
            Label(tab.rawValue, systemImage: tab.systemImage)
        }
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.2) : nil)
        .foregroundStyle(isSelected ? .primary : .secondary)
        #if os(macOS)
            .buttonStyle(.plain)
        #endif
    }

    private var isSelected: Bool {
        navigationManager.selectedTab == tab
    }
}

/// Individual management section button
struct ManagementSectionButton: View {
    let section: ManagementSection
    @Environment(NavigationManager.self) private var navigationManager

    var body: some View {
        Button {
            navigationManager.selectedTab = .management
            navigationManager.selectedManagementSection = section
        } label: {
            Label(section.rawValue, systemImage: section.systemImage)
        }
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.2) : nil)
        .foregroundStyle(isSelected ? .primary : .secondary)
        #if os(macOS)
            .buttonStyle(.plain)
        #endif
    }

    private var isSelected: Bool {
        navigationManager.selectedTab == .management && navigationManager.selectedManagementSection == section
    }
}

// MARK: - Content Column

/// Content column showing list for selected section
struct ContentColumn: View {
    @Environment(NavigationManager.self) private var navigationManager

    var body: some View {
        @Bindable var nav = navigationManager

        switch navigationManager.selectedTab {
        case .dashboard:
            DashboardView()
        case .items:
            ItemListView(
                horizontalSizeClass: .regular,
                selectedItem: $nav.selectedItem,
                onNavigateToItem: { item in
                    nav.selectedItem = item
                }
            )
        case .management:
            ManagementListView(
                section: navigationManager.selectedManagementSection,
                selectedCategory: $nav.selectedCategory,
                selectedLocation: $nav.selectedLocation,
                selectedAuthor: $nav.selectedAuthor,
                selectedPositionSchema: $nav.selectedPositionSchema
            )
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Detail Column

/// Detail column showing detail view for selected entity
struct DetailColumn: View {
    @Environment(NavigationManager.self) private var navigationManager

    var body: some View {
        @Bindable var nav = navigationManager

        switch nav.selectedTab {
        case .dashboard:
            // Dashboard doesn't have a detail view
            ContentUnavailableView(
                "Dashboard",
                systemImage: "chart.bar",
                description: Text("View your storage overview")
            )
        case .items:
            if let item = nav.selectedItem {
                ItemDetailView(itemId: item.id)
                    .navigationDestination(for: StorageItem.self) { child in
                        ItemDetailView(itemId: child.id)
                    }
                    .id(item.id) // Forces clean NavigationStack recreation on item change
            } else {
                ContentUnavailableView(
                    "Select an item",
                    systemImage: "shippingbox",
                    description: Text("Choose an item from the list to view details")
                )
            }
        case .management:
            managementDetailView
        case .settings:
            @Bindable var nav = navigationManager

            NavigationStack(path: $nav.settingsNavigationPath) {
                ContentUnavailableView(
                    "Settings",
                    systemImage: "gearshape",
                    description: Text("Configure your app settings")
                )
                .navigationDestination(for: WebPage.self) { webPage in
                    WebPageView(webPage: webPage)
                }
            }
        }
    }

    @ViewBuilder
    private var managementDetailView: some View {
        @Bindable var nav = navigationManager

        switch nav.selectedManagementSection {
        case .categories:
            if let category = nav.selectedCategory {
                CategoryDetailView(categoryId: category.id)
                    .id(category.id)
            } else {
                ContentUnavailableView(
                    "Select a category",
                    systemImage: "folder",
                    description: Text("Choose a category from the list")
                )
            }
        case .locations:
            if let location = nav.selectedLocation {
                LocationDetailView(locationId: location.id)
                    .id(location.id)
            } else {
                ContentUnavailableView(
                    "Select a location",
                    systemImage: "mappin.circle",
                    description: Text("Choose a location from the list")
                )
            }
        case .authors:
            if let author = nav.selectedAuthor {
                AuthorDetailView(authorId: author.id)
                    .id(author.id)
            } else {
                ContentUnavailableView(
                    "Select an author",
                    systemImage: "person.circle",
                    description: Text("Choose an author from the list")
                )
            }
        case .positionSchemas:
            if let schema = nav.selectedPositionSchema {
                PositionSchemaDetailView(schemaId: schema.id)
                    .id(schema.id)
            } else {
                ContentUnavailableView(
                    "Select a schema",
                    systemImage: "doc.text",
                    description: Text("Choose a schema from the list")
                )
            }
        }
    }
}

// MARK: - Management List View

/// List view for management sections (used in sidebar content column)
struct ManagementListView: View {
    let section: ManagementSection
    @Binding var selectedCategory: RxStorageCore.Category?
    @Binding var selectedLocation: Location?
    @Binding var selectedAuthor: Author?
    @Binding var selectedPositionSchema: PositionSchema?

    var body: some View {
        switch section {
        case .categories:
            CategoryListView(horizontalSizeClass: .regular, selectedCategory: $selectedCategory)
        case .locations:
            LocationListView(horizontalSizeClass: .regular, selectedLocation: $selectedLocation)
        case .authors:
            AuthorListView(horizontalSizeClass: .regular, selectedAuthor: $selectedAuthor)
        case .positionSchemas:
            PositionSchemaListView(horizontalSizeClass: .regular, selectedSchema: $selectedPositionSchema)
        }
    }
}

#Preview {
    SidebarNavigationView()
        .environment(NavigationManager())
}
