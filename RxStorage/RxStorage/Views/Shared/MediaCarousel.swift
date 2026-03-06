//
//  MediaCarousel.swift
//  RxStorage
//
//  Cross-platform media carousel: TabView page style on iOS, custom carousel on macOS
//

import SwiftUI

/// A cross-platform media carousel view
struct MediaCarousel<Content: View, Item: Identifiable>: View {
    let items: [Item]
    @Binding var selectedIndex: Int
    let content: (Item) -> Content

    init(
        items: [Item],
        selectedIndex: Binding<Int>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        _selectedIndex = selectedIndex
        self.content = content
    }

    var body: some View {
        #if os(iOS)
            TabView(selection: $selectedIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    content(item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .automatic : .never))
        #else
            MacOSCarousel(
                items: items,
                selectedIndex: $selectedIndex,
                content: content
            )
        #endif
    }
}

#if os(macOS)
    /// Custom carousel implementation for macOS with peeking and smooth transitions
    private struct MacOSCarousel<Content: View, Item: Identifiable>: View {
        let items: [Item]
        @Binding var selectedIndex: Int
        let content: (Item) -> Content

        @State private var dragOffset: CGFloat = 0

        private var canGoBack: Bool {
            selectedIndex > 0
        }

        private var canGoForward: Bool {
            selectedIndex < items.count - 1
        }

        var body: some View {
            GeometryReader { geometry in
                let itemWidth = geometry.size.width

                ZStack {
                    // Items stack with peeking effect (clipped in a fixed-size container)
                    HStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                            content(item)
                                .frame(width: itemWidth, height: geometry.size.height)
                        }
                    }
                    .offset(x: -CGFloat(selectedIndex) * itemWidth + dragOffset)
                    .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: selectedIndex)
                    .frame(width: itemWidth, height: geometry.size.height, alignment: .leading)
                    .clipped()

                    // Navigation arrows (outside clipped area)
                    if !items.isEmpty {
                        HStack {
                            // Left arrow
                            Button {
                                withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedIndex = max(0, selectedIndex - 1)
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(.black.opacity(canGoBack ? 0.5 : 0.2))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .opacity(canGoBack ? 1 : 0.4)
                            .disabled(!canGoBack)
                            .padding(.leading, 16)

                            Spacer()

                            // Right arrow
                            Button {
                                withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedIndex = min(items.count - 1, selectedIndex + 1)
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(.black.opacity(canGoForward ? 0.5 : 0.2))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .opacity(canGoForward ? 1 : 0.4)
                            .disabled(!canGoForward)
                            .padding(.trailing, 16)
                        }

                        // Page indicator dots
                        VStack {
                            Spacer()
                            HStack(spacing: 8) {
                                ForEach(0 ..< items.count, id: \.self) { index in
                                    Circle()
                                        .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.5))
                                        .frame(width: 8, height: 8)
                                        .onTapGesture {
                                            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8)) {
                                                selectedIndex = index
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.black.opacity(0.3))
                            .clipShape(Capsule())
                            .padding(.bottom, 16)
                        }
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Allow drag with resistance at boundaries
                            let translation = value.translation.width
                            if (selectedIndex == 0 && translation > 0) ||
                                (selectedIndex == items.count - 1 && translation < 0)
                            {
                                // Apply resistance at boundaries
                                dragOffset = translation * 0.3
                            } else {
                                dragOffset = translation
                            }
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            let velocity = value.predictedEndTranslation.width - value.translation.width

                            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.8)) {
                                // Consider both drag distance and velocity
                                if value.translation.width > threshold || velocity > 200, selectedIndex > 0 {
                                    selectedIndex -= 1
                                } else if value.translation.width < -threshold || velocity < -200, selectedIndex < items.count - 1 {
                                    selectedIndex += 1
                                }
                                dragOffset = 0
                            }
                        }
                )
            }
        }
    }
#endif

// MARK: - Preview

#Preview("Media Carousel") {
    struct PreviewItem: Identifiable {
        let id: Int
        let color: Color
    }

    struct PreviewWrapper: View {
        @State private var selectedIndex = 0
        let items = [
            PreviewItem(id: 0, color: .blue),
            PreviewItem(id: 1, color: .green),
            PreviewItem(id: 2, color: .orange),
        ]

        var body: some View {
            MediaCarousel(items: items, selectedIndex: $selectedIndex) { item in
                item.color
                    .overlay {
                        Text("Item \(item.id + 1)")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                    }
            }
            .frame(height: 300)
        }
    }

    return PreviewWrapper()
}
