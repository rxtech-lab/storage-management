//
//  EntityNavigation.swift
//  RxStorage
//
//  Navigation value type for entity detail navigation from item detail
//

import Foundation

/// Lightweight navigation value for navigating to entity detail pages
enum EntityNavigation: Hashable {
    case category(id: String)
    case location(id: String)
    case author(id: String)
}
