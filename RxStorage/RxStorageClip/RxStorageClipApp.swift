//
//  RxStorageClipApp.swift
//  RxStorageClip
//
//  App Clips entry point
//

import SwiftUI
import RxStorageCore

@main
struct RxStorageClipApp: App {
    var body: some Scene {
        WindowGroup {
            ClipRootView()
        }
    }
}
