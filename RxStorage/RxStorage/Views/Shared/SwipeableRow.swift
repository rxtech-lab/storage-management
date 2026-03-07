//
//  SwipeableRow.swift
//  RxStorage
//
//  Swipeable row component with leading and trailing actions
//

import SwiftUI

// MARK: - Swipe Action

struct SwipeAction {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
}

// MARK: - Swipeable Row

struct SwipeableRow<Content: View>: View {
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var isHorizontalDrag: Bool?

    private let actionWidth: CGFloat = 70
    private let threshold: CGFloat = 50

    init(
        leadingActions: [SwipeAction] = [],
        trailingActions: [SwipeAction] = [],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.leadingActions = leadingActions
        self.trailingActions = trailingActions
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Actions container
            HStack(spacing: 0) {
                // Leading actions (revealed when swiping right)
                if !leadingActions.isEmpty && offset > 0 {
                    ForEach(Array(leadingActions.enumerated()), id: \.offset) { _, action in
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                offset = 0
                            }
                            action.action()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: action.icon)
                                    .font(.title3)
                                Text(action.title)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.white)
                            .frame(width: actionWidth)
                            .frame(maxHeight: .infinity)
                            .background(action.color)
                        }
                    }
                }

                Spacer()

                // Trailing actions (revealed when swiping left)
                if !trailingActions.isEmpty && offset < 0 {
                    ForEach(Array(trailingActions.enumerated()), id: \.offset) { _, action in
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                offset = 0
                            }
                            action.action()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: action.icon)
                                    .font(.title3)
                                Text(action.title)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.white)
                            .frame(width: actionWidth)
                            .frame(maxHeight: .infinity)
                            .background(action.color)
                        }
                    }
                }
            }

            // Main content
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { geo in
                        Color.secondarySystemGroupedBackground
                            .preference(key: ContentHeightKey.self, value: geo.size.height)
                    }
                )
                .onPreferenceChange(ContentHeightKey.self) { height in
                    contentHeight = height
                }
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let horizontal = abs(value.translation.width)
                            let vertical = abs(value.translation.height)

                            // Determine drag direction on first significant movement
                            if isHorizontalDrag == nil, horizontal > 10 || vertical > 10 {
                                isHorizontalDrag = horizontal > vertical
                            }

                            // Only apply offset for horizontal drags
                            guard isHorizontalDrag == true else { return }

                            let translation = value.translation.width

                            // Limit swipe based on available actions
                            let maxLeading = leadingActions.isEmpty ? 0 : CGFloat(leadingActions.count) * actionWidth
                            let maxTrailing = trailingActions.isEmpty ? 0 : CGFloat(trailingActions.count) * actionWidth

                            if translation > 0 {
                                // Swiping right (reveal leading actions)
                                offset = min(translation, maxLeading)
                            } else {
                                // Swiping left (reveal trailing actions)
                                offset = max(translation, -maxTrailing)
                            }
                        }
                        .onEnded { value in
                            defer { isHorizontalDrag = nil }

                            // Only process if this was a horizontal drag
                            guard isHorizontalDrag == true else { return }

                            let translation = value.translation.width

                            withAnimation(.easeOut(duration: 0.2)) {
                                if translation > threshold, !leadingActions.isEmpty {
                                    // Snap to show leading actions
                                    offset = CGFloat(leadingActions.count) * actionWidth
                                } else if translation < -threshold, !trailingActions.isEmpty {
                                    // Snap to show trailing actions
                                    offset = -CGFloat(trailingActions.count) * actionWidth
                                } else {
                                    // Reset
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }
}

// MARK: - Preference Key for Content Height

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
