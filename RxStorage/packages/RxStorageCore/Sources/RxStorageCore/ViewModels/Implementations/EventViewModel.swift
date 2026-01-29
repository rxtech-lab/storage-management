//
//  EventViewModel.swift
//  RxStorageCore
//
//  Created by Qiwei Li on 1/29/26.
//

@preconcurrency import Combine
import SwiftUI

public enum AppEvent: Sendable {
    case itemCreated(id: Int)
    case itemUpdated(id: Int)
    case itemDeleted(id: Int)
    case categoryCreated(id: Int)
    case categoryUpdated(id: Int)
    case categoryDeleted(id: Int)
    case locationCreated(id: Int)
    case locationUpdated(id: Int)
    case locationDeleted(id: Int)
    case authorCreated(id: Int)
    case authorUpdated(id: Int)
    case authorDeleted(id: Int)
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
