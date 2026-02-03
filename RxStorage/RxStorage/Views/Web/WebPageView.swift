//
//  WebPageView.swift
//  RxStorage
//
//  In-app web page view with navigation controls
//

import SwiftUI
import WebKit

struct WebPageView: View {
    let webPage: WebPage

    @State private var estimatedProgress: Double = 0
    @State private var wkWebpage = WebKit.WebPage()

    var body: some View {
        VStack(spacing: 0) {
            if wkWebpage.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            WebView(wkWebpage)
                .ignoresSafeArea(.container, edges: .bottom)
                .opacity(wkWebpage.isLoading ? 0 : 1)
                .onAppear {
                    wkWebpage.load(webPage.url)
                }
        }
        .navigationTitle(webPage.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if wkWebpage.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
            }
    }
}
