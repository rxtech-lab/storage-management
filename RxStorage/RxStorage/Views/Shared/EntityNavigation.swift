//
//  EntityNavigation.swift
//  RxStorage
//
//  Navigation value type for entity detail navigation from item detail
//

import Foundation
import RxStorageCore
import SwiftUI

/// Lightweight navigation value for navigating to entity detail pages
enum EntityNavigation: Hashable {
    case category(id: String)
    case location(id: String)
    case author(id: String)
    case tag(id: String)
}

extension View {
    /// Declares navigation destinations for both entity detail views and item detail views.
    /// Apply this at the NavigationStack root level to avoid duplicate declarations.
    func entityNavigationDestinations() -> some View {
        navigationDestination(for: EntityNavigation.self) { nav in
            switch nav {
            case let .category(id):
                CategoryDetailView(categoryId: id)
            case let .location(id):
                LocationDetailView(locationId: id)
            case let .author(id):
                AuthorDetailView(authorId: id)
            case let .tag(id):
                TagDetailView(tagId: id)
            }
        }
        .navigationDestination(for: StorageItem.self) { item in
            ItemDetailView(itemId: item.id)
        }
    }
}
