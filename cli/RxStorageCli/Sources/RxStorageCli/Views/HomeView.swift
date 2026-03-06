import SwiftTUI

struct HomeView: View, @unchecked Sendable {
    @State private var authState: AuthState = .unauthenticated

    var body: some View {
        VStack {
            switch authState {
            case .authenticated(let user):
                Text("RxStorage CLI - \(user.name ?? user.email ?? user.id)")
                Divider()
                StorageItemList(onSignOut: signOut)
            case .unauthenticated:
                Text("RxStorage CLI")
                Text("Not signed in")
                Button("Sign In") {
                    signIn()
                }
                .focusable(false)
            case .authenticating:
                Text("RxStorage CLI")
                Text("Opening browser for sign in...")
                Text("URL copied to clipboard - paste in browser if needed")
            case .error(let message):
                Text("RxStorage CLI")
                Text("Error: \(message)")
                Button("Retry Sign In") {
                    signIn()
                }
                .focusable(false)
            default:
                Text("...")
            }
        }
        .task {
            let authManager = CLIOAuthManager(configuration: .fromEnvironment)
            let state = await authManager.checkExistingAuth()
            authState = state
        }
    }

    private func signIn() {
        authState = .authenticating
        Task {
            let authManager = CLIOAuthManager(configuration: .fromEnvironment)
            do {
                let user = try await authManager.authenticate { url in
                    // URL is copied to clipboard by openBrowser
                }
                authState = .authenticated(user)
            } catch {
                authState = .error(String(describing: error))
            }
        }
    }

    private func signOut() {
        let authManager = CLIOAuthManager(configuration: .fromEnvironment)
        try? authManager.logout()
        authState = .unauthenticated
    }
}
