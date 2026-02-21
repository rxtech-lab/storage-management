//
//  NFCLockSheet.swift
//  RxStorage
//
//  Bottom sheet for locking an NFC tag after a successful write
//

import LocalAuthentication
import RxStorageCore
import SwiftUI

#if os(iOS)

    struct NFCLockSheet<Writer: NFCWriterProtocol>: View {
        let nfcWriter: Writer
        let onDismiss: () -> Void

        @State private var isLocking = false
        @State private var lockSuccess = false
        @State private var lockError: String?

        var body: some View {
            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                Spacer()

                // Main content with animation
                Group {
                    if lockSuccess {
                        lockSuccessContent
                    } else {
                        writeSuccessContent
                    }
                }
                .animation(.spring(duration: 0.4), value: lockSuccess)

                Spacer()

                // Bottom buttons
                bottomButtons
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(20)
            .interactiveDismissDisabled(isLocking)
        }

        // MARK: - Write Success Content

        private var writeSuccessContent: some View {
            VStack(spacing: 0) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(.bottom, 20)

                Text("NFC Write Successful")
                    .font(.title2.weight(.bold))
                    .padding(.bottom, 8)

                Text("The URL has been written to the NFC tag.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 28)

                // Lock section with card-style background
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .symbolRenderingMode(.hierarchical)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lock This Tag?")
                                .font(.headline)

                            Text("Permanently prevent overwriting")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    Text("Locking prevents the tag from being overwritten by other devices. This action cannot be undone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let lockError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(lockError)
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                }
                .padding(.horizontal, 20)
            }
        }

        // MARK: - Lock Success Content

        private var lockSuccessContent: some View {
            VStack(spacing: 0) {
                // Locked icon with shield
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 80, height: 80)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(.bottom, 20)

                Text("Tag Locked")
                    .font(.title2.weight(.bold))
                    .padding(.bottom, 8)

                Text("The NFC tag has been permanently locked and cannot be overwritten.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Confirmation badge
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Protected")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(Color.green.opacity(0.12))
                }
                .padding(.top, 20)
            }
        }

        // MARK: - Bottom Buttons

        private var bottomButtons: some View {
            VStack(spacing: 12) {
                if !lockSuccess {
                    Button {
                        Task { await lockTag() }
                    } label: {
                        HStack(spacing: 8) {
                            if isLocking {
                                ProgressView()
                                    .tint(.white)
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "lock.fill")
                            }
                            Text(isLocking ? "Locking..." : "Lock Tag")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .buttonBorderShape(.roundedRectangle(radius: 12))
                    .disabled(isLocking)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }

        // MARK: - Actions

        private func lockTag() async {
            // First, authenticate with biometrics
            let authenticated = await authenticateWithBiometrics()
            guard authenticated else { return }

            isLocking = true
            lockError = nil
            defer { isLocking = false }

            do {
                try await nfcWriter.lockNfcTag()
                withAnimation(.spring(duration: 0.4)) {
                    lockSuccess = true
                }
            } catch NFCWriterError.cancelled {
                // User cancelled - do nothing
            } catch {
                lockError = error.localizedDescription
            }
        }

        private func authenticateWithBiometrics() async -> Bool {
            let context = LAContext()
            var error: NSError?

            // Check if biometric authentication is available
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                // Biometrics not available, allow proceeding without it
                return true
            }

            do {
                return try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "Authenticate to permanently lock this NFC tag"
                )
            } catch {
                // User cancelled or authentication failed
                if let laError = error as? LAError, laError.code == .userCancel {
                    return false
                }
                lockError = "Authentication failed"
                return false
            }
        }
    }

#endif

// MARK: - Preview

#if os(iOS) && DEBUG

    private actor PreviewNFCWriter: NFCWriterProtocol {
        var shouldSucceed = true

        func writeToNfcChip(url _: String, allowOverwrite _: Bool) async throws {}

        func lockNfcTag() async throws {
            try await Task.sleep(for: .seconds(1))
            if !shouldSucceed {
                throw NFCWriterError.writeFailed("Preview error")
            }
        }
    }

    #Preview("Write Success") {
        NFCLockSheet(nfcWriter: PreviewNFCWriter()) {
            print("Dismissed")
        }
    }

    #Preview("Locked State") {
        NFCLockSheet(nfcWriter: PreviewNFCWriter()) {
            print("Dismissed")
        }
    }

#endif
