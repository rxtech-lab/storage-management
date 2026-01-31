//
//  RxStorageClipsApp.swift
//  RxStorageClips
//
//  App Clips entry point - uses AppClipRootView for deep link navigation
//

import SwiftUI

@main
struct RxStorageClipsApp: App {
    var body: some Scene {
        WindowGroup {
            AppClipRootView()
        }
    }
}
