//
//  ContentView.swift
//  RxStorage
//
//  Created by Qiwei Li on 1/27/26.
//

import SwiftUI
import RxStorageCore

struct ContentView: View {
    @State private var authManager = OAuthManager.shared

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                RootView()
            } else {
                LoginView()
            }
        }
    }
}

/// Login screen
struct LoginView: View {
    @State private var authManager = OAuthManager.shared
    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // App Icon/Logo
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("RxStorage")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Storage Management System")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        Task {
                            await signIn()
                        }
                    } label: {
                        HStack {
                            if isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("Sign In with OAuth")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isAuthenticating)
                    .padding(.horizontal, 32)
                }

                Spacer()
            }
            .navigationTitle("Welcome")
        }
    }

    private func signIn() async {
        isAuthenticating = true
        errorMessage = nil

        do {
            try await authManager.authenticate()
        } catch {
            errorMessage = error.localizedDescription
        }

        isAuthenticating = false
    }
}

#Preview {
    ContentView()
}

#Preview("Login") {
    LoginView()
}
