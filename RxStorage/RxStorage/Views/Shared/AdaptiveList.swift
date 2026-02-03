//
//  AdaptiveList.swift
//  RxStorage
//
//  Created by Qiwei Li on 2/4/26.
//

import SwiftUI

/// A reusable list component that adapts its behavior based on horizontal size class
/// - On iPad (regular): Uses List with selection binding for split-view navigation
/// - On iPhone (compact): Uses List without selection (NavigationLink handles navigation)
struct AdaptiveList<SelectionValue: Hashable, Content: View>: View {
    let horizontalSizeClass: UserInterfaceSizeClass

    @Binding var selection: SelectionValue?
    @ViewBuilder let content: () -> Content

    init(
        horizontalSizeClass: UserInterfaceSizeClass,
        selection: Binding<SelectionValue?>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.horizontalSizeClass = horizontalSizeClass
        self._selection = selection
        self.content = content
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                List(selection: $selection) {
                    content()
                }
                .listStyle(.automatic)
            } else {
                List {
                    content()
                }
                .listStyle(.automatic)
            }
        }
    }
}
