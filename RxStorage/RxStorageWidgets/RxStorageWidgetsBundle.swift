//
//  RxStorageWidgetsBundle.swift
//  RxStorageWidgets
//
//  Widget extension hosting the ISO job Live Activity
//

import SwiftUI
import WidgetKit

@main
struct RxStorageWidgetsBundle: WidgetBundle {
    var body: some Widget {
        IsoJobLiveActivity()
    }
}
