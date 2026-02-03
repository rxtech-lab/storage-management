//
//  WebPage.swift
//  RxStorage
//
//  Web page destination for in-app browsing
//

import Foundation

/// Represents a web page that can be displayed in-app
struct WebPage: Hashable, Identifiable {
    let id: String
    let title: String
    let url: URL

    init(id: String, title: String, url: URL) {
        self.id = id
        self.title = title
        self.url = url
    }

    // Predefined web pages for settings
    static let helpAndSupport = WebPage(
        id: "help",
        title: "Help & Support",
        url: URL(string: "https://storage.rxlab.app/support")!
    )

    static let privacyPolicy = WebPage(
        id: "privacy",
        title: "Privacy Policy",
        url: URL(string: "https://storage.rxlab.app/privacy")!
    )

    static let termsOfService = WebPage(
        id: "tos",
        title: "Terms of Service",
        url: URL(string: "https://storage.rxlab.app/terms")!
    )
}
