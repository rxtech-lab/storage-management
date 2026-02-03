//
//  LoadingOverlay.swift
//  Loading overlay with dialog design
//
//  Created by Qiwei Li on 1/29/26.
//
import SwiftUI

struct LoadingOverlay: View {
    /**
     Title of the loading progress view. If nil, show default Loading
     */
    let title: String?

    init(title: String? = nil) {
        self.title = title
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.1) // Semi-transparent background
                .edgesIgnoringSafeArea(.all)

            ProgressView(title ?? "Loading") // The spinner and text
                .padding()
                #if os(iOS)
                .background(Color(.systemBackground))
                #elseif os(macOS)
                .background(Color(nsColor: .windowBackgroundColor))
                #endif
                .cornerRadius(12)
        }
    }
}

#Preview {
    LoadingOverlay()
}
