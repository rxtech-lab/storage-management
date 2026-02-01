//
//  EventViewModel.swift
//  RxStorageCore
//
//  Created by Qiwei Li on 1/29/26.
//

@preconcurrency import Combine
import SwiftUI

public enum AppEvent: Sendable {
    // Item events
    case itemCreated(id: Int)
    case itemUpdated(id: Int)
    case itemDeleted(id: Int)

    // Category events
    case categoryCreated(id: Int)
    case categoryUpdated(id: Int)
    case categoryDeleted(id: Int)

    // Location events
    case locationCreated(id: Int)
    case locationUpdated(id: Int)
    case locationDeleted(id: Int)

    // Author events
    case authorCreated(id: Int)
    case authorUpdated(id: Int)
    case authorDeleted(id: Int)

    // Position schema events
    case positionSchemaCreated(id: Int)
    case positionSchemaUpdated(id: Int)
    case positionSchemaDeleted(id: Int)

    // Content events (tied to item)
    case contentCreated(itemId: Int, contentId: Int)
    case contentUpdated(itemId: Int, contentId: Int)
    case contentDeleted(itemId: Int, contentId: Int)

    // Child relationship events
    case childAdded(parentId: Int, childId: Int)
    case childRemoved(parentId: Int, childId: Int)

    // Position events (tied to item)
    case positionCreated(itemId: Int, positionId: Int)
    case positionDeleted(itemId: Int, positionId: Int)

    // Error event
    case error(message: String)
}

@Observable
@MainActor
public final class EventViewModel {
    private let subject = PassthroughSubject<AppEvent, Never>()
    private var cancellables = Set<AnyCancellable>()

    public init() {}

    /// Emit an event to all listeners
    public func emit(_ event: AppEvent) {
        subject.send(event)
    }

    /// AsyncStream for consuming events in async contexts
    public var stream: AsyncStream<AppEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(20)) { continuation in
            let cancellable = subject.sink { event in
                continuation.yield(event)
            }

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    /// Subscribe with a Combine sink (for non-async contexts)
    public func subscribe(_ handler: @escaping (AppEvent) -> Void) -> AnyCancellable {
        subject.sink(receiveValue: handler)
    }
}
