//
//  IsoJobFormatting.swift
//  RxStorage
//
//  Display helpers for ISO jobs reported by iso-burner
//

import RxStorageCore
import SwiftUI

extension IsoJobStatus {
    var displayName: String {
        switch self {
        case .running: "Running"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        case .stopped: "Stopped"
        }
    }

    var color: Color {
        switch self {
        case .running: .blue
        case .completed: .green
        case .failed: .red
        case .cancelled, .stopped: .orange
        }
    }

    var systemImage: String {
        switch self {
        case .running: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .cancelled: "slash.circle"
        case .stopped: "pause.circle"
        }
    }
}

extension IsoJobKind {
    var displayName: String {
        switch self {
        case .generate: "Generate ISO"
        case .burn: "Burn discs"
        case .upload: "Upload content"
        }
    }

    var systemImage: String {
        switch self {
        case .generate: "doc.zipper"
        case .burn: "opticaldisc"
        case .upload: "arrow.up.doc"
        }
    }

    /// Noun for the job's count, e.g. "2 of 4 discs"
    var unitName: String {
        switch self {
        case .generate: "ISO files"
        case .burn: "discs"
        case .upload: "files"
        }
    }
}

enum IsoJobFormat {
    /// Formats bytes with binary units, matching the iso-burner CLI
    static func bytes(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .binary)
    }

    static func percent(_ fraction: Double) -> String {
        min(max(fraction, 0), 1).formatted(.percent.precision(.fractionLength(0)))
    }
}

/// Capsule showing an ISO job's status
struct IsoJobStatusBadge: View {
    let status: IsoJobStatus

    var body: some View {
        Label(status.displayName, systemImage: status.systemImage)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(status.color)
            .background(status.color.opacity(0.15))
            .clipShape(Capsule())
            .accessibilityIdentifier("iso-job-status")
    }
}

extension View {
    /// Refreshes every `interval` while `isActive` is true, for jobs still reporting progress
    func liveRefresh(
        while isActive: Bool,
        every interval: Duration = .seconds(5),
        perform refresh: @escaping () async -> Void
    ) -> some View {
        task(id: isActive) {
            guard isActive else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                await refresh()
            }
        }
    }
}

extension IsoJobTask {
    /// Drive letter and drive model of a drive row. iso-burner reports drive
    /// rows as "E · Vendor Model" on Windows and "1 · Vendor Model" on macOS,
    /// so the letter is the part before " · ".
    /// Returns nil for other rows or names without a short drive letter.
    var driveLetter: (letter: String, model: String)? {
        guard section == .drive else { return nil }
        let parts = name.components(separatedBy: " · ")
        guard parts.count >= 2 else { return nil }
        let letter = parts[0].trimmingCharacters(in: .whitespaces)
        guard (1 ... 2).contains(letter.count), letter.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        return (letter.uppercased(), parts.dropFirst().joined(separator: " · "))
    }
}
