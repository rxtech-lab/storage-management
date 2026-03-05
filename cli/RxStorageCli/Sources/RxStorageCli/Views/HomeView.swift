import SwiftTUI

struct HomeView: View {
    @State private var authState: AuthState

    init() {
        // Check locally if we have a valid token (no network call)
        let tokenStorage = FileTokenStorage()
        if tokenStorage.getAccessToken() != nil, !tokenStorage.isTokenExpired() {
            self._authState = State(initialValue: .hasToken)
        } else {
            self._authState = State(initialValue: .unauthenticated)
        }
    }

    var body: some View {
        VStack {
            Text("RxStorage CLI")

            VStack {
                switch authState {
                case .unauthenticated:
                    Text("Not signed in")
                    Button("Sign In") {
                        signIn()
                    }
                case .hasToken:
                    Text("Signed in (token valid)")
                    Button("Sign Out") {
                        signOut()
                    }
                case .authenticated(let user):
                    Text("Signed in as: \(user.name ?? user.email ?? user.id)")
                    Button("Sign Out") {
                        signOut()
                    }
                case .authenticating:
                    Text("Opening browser for sign in...")
                    Text("URL copied to clipboard - paste in browser if needed")
                case .error(let message):
                    Text("Error: \(message)")
                    Button("Retry Sign In") {
                        signIn()
                    }
                default:
                    Text("...")
                }
            }.border(.blue)
        }
    }

    @MainActor
    private func signIn() {
        authState = .authenticating
        Task { @MainActor in
            let authManager = CLIOAuthManager(configuration: .fromEnvironment)
            do {
                let user = try await authManager.authenticate { url in
                    // URL is copied to clipboard by openBrowser
                }
                authState = .authenticated(user)
            } catch {
                authState = .error(error.localizedDescription)
            }
        }
    }

    private func signOut() {
        let authManager = CLIOAuthManager(configuration: .fromEnvironment)
        try? authManager.logout()
        authState = .unauthenticated
    }
}
