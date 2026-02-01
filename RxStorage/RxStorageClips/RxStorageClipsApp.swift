//
//  RxStorageClipsApp.swift
//  RxStorageClips
//
//  App Clips entry point - uses AppClipRootView for deep link navigation
//

import RxStorageCore
import SwiftUI

@main
struct RxStorageClipsApp: App {
    // Detail view models injected via environment
    @State private var categoryDetailViewModel = CategoryDetailViewModel()
    @State private var authorDetailViewModel = AuthorDetailViewModel()
    @State private var locationDetailViewModel = LocationDetailViewModel()
    @State private var positionSchemaDetailViewModel = PositionSchemaDetailViewModel()
    @State private var eventViewModel = EventViewModel()

    var body: some Scene {
        WindowGroup {
            AppClipRootView()
                .environment(categoryDetailViewModel)
                .environment(authorDetailViewModel)
                .environment(locationDetailViewModel)
                .environment(positionSchemaDetailViewModel)
                .environment(eventViewModel)
        }
    }
}
