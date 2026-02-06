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

    #if os(iOS)
        @State private var showQrCodeScanner = false
        @State private var isLoadingFromQR = false
        private let itemService = ItemService()
        private let qrCodeService = QrCodeService()
    #endif

    var body: some View {
        @Bindable var nav = navigationManager

        TabView(selection: $nav.selectedTab) {
            // Dashboard Tab
            NavigationStack(path: $nav.dashboardNavigationPath) {
                DashboardView()
                #if os(iOS)
                    .qrCodeScannerToolbar(isPresented: $showQrCodeScanner)
                #endif
                    .navigationDestination(for: StorageItem.self) { item in
                        ItemDetailView(itemId: item.id)
                    }
            }
            .tabItem {
                Label(AppTab.dashboard.rawValue, systemImage: AppTab.dashboard.systemImage)
            }
            .tag(AppTab.dashboard)
            .accessibilityIdentifier("tab-dashboard")

            // Items Tab
            NavigationStack(path: $nav.itemsNavigationPath) {
                ItemListView(
                    horizontalSizeClass: .compact,
                    onNavigateToItem: { item in
                        nav.itemsNavigationPath.append(item)
                    }
                )
                #if os(iOS)
                .qrCodeScannerToolbar(isPresented: $showQrCodeScanner)
                #endif
                .navigationDestination(for: StorageItem.self) { item in
                    ItemDetailView(itemId: item.id)
                }
            }
            .tabItem {
                Label(AppTab.items.rawValue, systemImage: AppTab.items.systemImage)
            }
            .tag(AppTab.items)
            .accessibilityIdentifier("tab-items")

            // Management Tab
            NavigationStack(path: $nav.managementNavigationPath) {
                ManagementView()
                #if os(iOS)
                    .qrCodeScannerToolbar(isPresented: $showQrCodeScanner)
                #endif
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
            .accessibilityIdentifier("tab-management")

            // Settings Tab
            NavigationStack(path: $nav.settingsNavigationPath) {
                SettingsView()
                #if os(iOS)
                    .qrCodeScannerToolbar(isPresented: $showQrCodeScanner)
                #endif
                    .navigationDestination(for: WebPage.self) { webPage in
                        WebPageView(webPage: webPage)
                    }
            }
            .tabItem {
                Label(AppTab.settings.rawValue, systemImage: AppTab.settings.systemImage)
            }
            .tag(AppTab.settings)
            .accessibilityIdentifier("tab-settings")
        }
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

#Preview {
    TabBarView()
        .environment(NavigationManager())
}
