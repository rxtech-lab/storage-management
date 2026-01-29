//
//  ItemPreviewViewModelProtocol.swift
//  RxStorageCore
//
//  Item preview view model protocol for App Clips
//

import Foundation
import Observation

/// Protocol for item preview view model
@MainActor
public protocol ItemPreviewViewModelProtocol: AnyObject, Observable {
    var preview: ItemPreview? { get }
    var isLoading: Bool { get }
    var error: Error? { get }
    var requiresAuthentication: Bool { get }

    func fetchPreview(id: Int) async
}
