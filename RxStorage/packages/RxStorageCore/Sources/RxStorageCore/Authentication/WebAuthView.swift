//
//  WebAuthView.swift
//  RxStorageCore
//
//  WKWebView-based authentication for macOS
//

#if os(macOS)
    import AppKit
    import Logging
    import WebKit

    /// Result of the web authentication flow
    public enum WebAuthResult {
        case success(URL)
        case cancelled
        case error(Error)
    }

    /// WKWebView-based authentication window controller for macOS
    /// Used instead of ASWebAuthenticationSession to avoid threading issues
    @MainActor
    public class WebAuthWindowController: NSObject {
        private let logger = Logger(label: "com.rxlab.rxstorage.WebAuthWindowController")

        private var window: NSWindow?
        private var webView: WKWebView?
        private let authURL: URL
        private let callbackScheme: String
        private var continuation: CheckedContinuation<URL, Error>?

        public init(authURL: URL, callbackScheme: String) {
            self.authURL = authURL
            self.callbackScheme = callbackScheme
            super.init()
        }

        /// Start the authentication flow and return the callback URL
        public func start() async throws -> URL {
            logger.info("Starting WebAuthWindowController")

            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.setupAndShowWindow()
            }
        }

        private func setupAndShowWindow() {
            logger.debug("Setting up authentication window")

            // Create web view configuration
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .nonPersistent() // Ephemeral session

            // Create web view
            let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 500, height: 700), configuration: config)
            webView.navigationDelegate = self
            self.webView = webView

            // Create window
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 700),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Sign In"
            window.contentView = webView
            window.center()
            window.delegate = self
            self.window = window

            // Load the auth URL
            logger.info("Loading auth URL: \(authURL)")
            let request = URLRequest(url: authURL)
            webView.load(request)

            // Show window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        private func complete(with result: Result<URL, Error>) {
            logger.info("Completing authentication")

            // Capture continuation before cleanup
            guard let continuation = continuation else {
                logger.warning("No continuation to resume")
                return
            }
            self.continuation = nil

            // Clear delegate to prevent further callbacks
            window?.delegate = nil
            webView?.navigationDelegate = nil

            // Hide window instead of closing (user can close manually)
            window?.orderOut(nil)

            // Resume continuation
            switch result {
            case let .success(url):
                continuation.resume(returning: url)
            case let .failure(error):
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - WKNavigationDelegate

    extension WebAuthWindowController: WKNavigationDelegate {
        @MainActor
        public func webView(_: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            logger.debug("Navigation to: \(url)")

            // Check if this is the callback URL
            if url.scheme?.lowercased() == callbackScheme.lowercased() {
                logger.info("Callback URL detected: \(url)")
                decisionHandler(.cancel)
                complete(with: .success(url))
                return
            }

            decisionHandler(.allow)
        }

        public func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            logger.error("Navigation failed: \(error.localizedDescription)")
            // Don't fail on navigation errors - user might still be able to authenticate
        }

        public func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
            // Check if the error is due to our custom URL scheme (which is expected)
            let nsError = error as NSError
            if nsError.domain == "WebKitErrorDomain", nsError.code == 102 {
                // Frame load interrupted - this happens when we intercept the callback URL
                return
            }
            logger.error("Provisional navigation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - NSWindowDelegate

    extension WebAuthWindowController: NSWindowDelegate {
        public func windowWillClose(_: Notification) {
            logger.info("Window will close, continuation: \(continuation != nil ? "exists" : "nil")")

            // If continuation hasn't been resumed yet, user cancelled
            if let continuation = continuation {
                self.continuation = nil
                webView?.navigationDelegate = nil
                window = nil
                webView = nil
                continuation.resume(throwing: OAuthError.userCancelled)
            }
        }
    }
#endif
