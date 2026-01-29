//
//  RxStorageApp.swift
//  RxStorage
//
//  Created by Qiwei Li on 1/27/26.
//

import RxStorageCore
import SwiftUI

@main
struct RxStorageApp: App {
    // Detail view models injected via environment
    @State private var categoryDetailViewModel = CategoryDetailViewModel()
    @State private var authorDetailViewModel = AuthorDetailViewModel()
    @State private var locationDetailViewModel = LocationDetailViewModel()
    @State private var eventViewModel = EventViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(categoryDetailViewModel)
                .environment(authorDetailViewModel)
                .environment(locationDetailViewModel)
                .environment(eventViewModel)
        }
    }
}
