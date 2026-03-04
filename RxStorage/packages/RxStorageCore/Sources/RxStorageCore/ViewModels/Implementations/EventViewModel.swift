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
    case itemCreated(id: String)
    case itemUpdated(id: String)
    case itemDeleted(id: String)

    // Category events
    case categoryCreated(id: String)
    case categoryUpdated(id: String)
    case categoryDeleted(id: String)

    // Location events
    case locationCreated(id: String)
    case locationUpdated(id: String)
    case locationDeleted(id: String)

    // Author events
    case authorCreated(id: String)
    case authorUpdated(id: String)
    case authorDeleted(id: String)

    // Position schema events
    case positionSchemaCreated(id: String)
    case positionSchemaUpdated(id: String)
    case positionSchemaDeleted(id: String)

    // Content events (tied to item)
    case contentCreated(itemId: String, contentId: String)
    case contentUpdated(itemId: String, contentId: String)
    case contentDeleted(itemId: String, contentId: String)

    // Child relationship events
    case childAdded(parentId: String, childId: String)
    case childRemoved(parentId: String, childId: String)

    // Position events (tied to item)
    case positionCreated(itemId: String, positionId: String)
    case positionDeleted(itemId: String, positionId: String)

    /// Error event
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
