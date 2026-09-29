//
//  IsoJobLiveActivity.swift
//  RxStorageWidgets
//
//  Lock Screen and Dynamic Island presentation of the user's running ISO
//  jobs. One activity lists up to three jobs; the server starts, updates and
//  ends it as iso-burner reports progress.
//

import ActivityKit
import RxStorageCore
import SwiftUI
import WidgetKit

typealias IsoJobActivityJob = IsoJobActivityAttributes.Job
typealias IsoJobActivityState = IsoJobActivityAttributes.ContentState

struct IsoJobLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IsoJobActivityAttributes.self) { context in
            IsoJobsLockScreenView(state: context.state)
                .widgetURL(context.state.jobs.first.map { IsoJobDeepLink.url(jobId: $0.id) })
        } dynamicIsland: { context in
            let state = context.state

            return DynamicIsland {
                // One job gets the full layout; several get a row each
                DynamicIslandExpandedRegion(.leading) {
                    if let job = state.singleJob {
                        IsoJobIcon(job: job)
                            .padding(.leading, 4)
                    } else {
                        Label("\(state.runningCount) ISO jobs", systemImage: "opticaldisc")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(state.tint)
                            .padding(.leading, 4)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let job = state.singleJob {
                        IsoJobTrailingValue(job: job)
                            .font(.title3)
                            .padding(.trailing, 4)
                    } else if state.hiddenCount > 0 {
                        IsoJobMoreBadge(count: state.hiddenCount)
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if let job = state.singleJob {
                        VStack(spacing: 2) {
                            Text(job.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(job.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Group {
                        if let job = state.singleJob {
                            VStack(alignment: .leading, spacing: 6) {
                                IsoJobProgressBar(job: job)
                                IsoJobDetailLine(job: job)
                            }
                        } else {
                            IsoJobRowList(jobs: state.jobs)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: state.singleJob?.kind.systemImage ?? "opticaldisc")
                    .foregroundStyle(state.tint)
            } compactTrailing: {
                IsoJobCountRing(state: state)
            } minimal: {
                IsoJobCountRing(state: state)
            }
            .widgetURL(state.jobs.first.map { IsoJobDeepLink.url(jobId: $0.id) })
            .keylineTint(state.tint)
        }
    }
}

// MARK: - Display Helpers

extension IsoJobActivityState {
    /// The only job, when the activity tracks exactly one
    var singleJob: IsoJobActivityJob? {
        jobs.count == 1 && hiddenCount == 0 ? jobs.first : nil
    }

    /// Red if a job failed, the final status once all jobs end, blue while running
    var tint: Color {
        if jobs.contains(where: { $0.status == .failed }) { return IsoJobStatus.failed.color }
        if runningCount == 0, let job = jobs.first { return job.status.color }
        return IsoJobStatus.running.color
    }
}

extension IsoJobActivityJob {
    /// "Burn discs · studio-mac", or the final status once the job ends
    var subtitle: String {
        let status = status == .running ? kind.displayName : status.displayName
        guard let hostName, !hostName.isEmpty else { return status }
        return "\(status) · \(hostName)"
    }
}

// MARK: - Lock Screen

struct IsoJobsLockScreenView: View {
    let state: IsoJobActivityState

    var body: some View {
        Group {
            if let job = state.singleJob {
                IsoJobDetailedRow(job: job)
            } else {
                IsoJobRowList(jobs: state.jobs)
            }
        }
        .padding(.vertical, 16)
        .padding(.leading, 16)
        // Keep the badge's corner clear of the rows' percentages
        .padding(.trailing, state.hiddenCount > 0 ? 44 : 16)
        .overlay(alignment: .topTrailing) {
            if state.hiddenCount > 0 {
                IsoJobMoreBadge(count: state.hiddenCount)
                    .padding(10)
            }
        }
    }
}

/// Full layout for a single job: title, host, progress and detail line
struct IsoJobDetailedRow: View {
    let job: IsoJobActivityJob

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IsoJobIcon(job: job)

                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(job.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                IsoJobTrailingValue(job: job)
                    .font(.title2)
            }

            IsoJobProgressBar(job: job)
            IsoJobDetailLine(job: job)
        }
    }
}

/// One compact row per job, for activities tracking several jobs
struct IsoJobRowList: View {
    let jobs: [IsoJobActivityJob]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(jobs.prefix(IsoJobActivityAttributes.maxListedJobs)) { job in
                Link(destination: IsoJobDeepLink.url(jobId: job.id)) {
                    IsoJobCompactRow(job: job)
                }
            }
        }
    }
}

struct IsoJobCompactRow: View {
    let job: IsoJobActivityJob

    var body: some View {
        HStack(spacing: 10) {
            IsoJobIcon(job: job, size: 28)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(job.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    IsoJobTrailingValue(job: job)
                        .font(.subheadline)
                }
                IsoJobProgressBar(job: job)
            }
        }
    }
}

// MARK: - Components

/// Job kind symbol on a tinted circle, badged with the status once the job ends
struct IsoJobIcon: View {
    let job: IsoJobActivityJob
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: job.kind.systemImage)
            .font(size > 32 ? .title3 : .footnote)
            .foregroundStyle(job.status.color)
            .frame(width: size, height: size)
            .background(job.status.color.opacity(0.18), in: Circle())
            .overlay(alignment: .bottomTrailing) {
                if job.status != .running {
                    Image(systemName: job.status.systemImage)
                        .font(.caption2)
                        .foregroundStyle(.white, job.status.color)
                        .background(Circle().fill(.background))
                        .offset(x: 2, y: 2)
                }
            }
    }
}

/// Percentage while running, status symbol once the job ends
struct IsoJobTrailingValue: View {
    let job: IsoJobActivityJob

    var body: some View {
        if job.status == .running {
            Text(IsoJobFormat.percent(job.progress))
                .fontWeight(.semibold)
                .monospacedDigit()
                .contentTransition(.numericText(value: job.progress))
        } else {
            Image(systemName: job.status.systemImage)
                .foregroundStyle(job.status.color)
        }
    }
}

struct IsoJobProgressBar: View {
    let job: IsoJobActivityJob

    var body: some View {
        ProgressView(value: min(max(job.progress, 0), 1))
            .tint(job.status.color)
    }
}

/// Error, CLI message, or "1 of 2 discs · 1.2 GB of 4.7 GB"
struct IsoJobDetailLine: View {
    let job: IsoJobActivityJob

    var body: some View {
        Text(detail)
            .font(.caption)
            .foregroundStyle(job.status == .failed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
            .lineLimit(1)
    }

    private var detail: String {
        if job.status == .failed, let error = job.error, !error.isEmpty {
            return error
        }
        if job.status == .running, let message = job.message, !message.isEmpty {
            return message
        }

        var parts: [String] = []
        if job.totalCount > 0 {
            parts.append("\(job.doneCount) of \(job.totalCount) \(job.kind.unitName)")
        }
        if job.totalBytes > 0 {
            parts.append("\(IsoJobFormat.bytes(job.doneBytes)) of \(IsoJobFormat.bytes(job.totalBytes))")
        }
        return parts.isEmpty ? job.status.displayName : parts.joined(separator: " · ")
    }
}

/// "+2" for running jobs the activity does not list
struct IsoJobMoreBadge: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(IsoJobStatus.running.color, in: Capsule())
            .accessibilityLabel("\(count) more running jobs")
    }
}

/// Number of running jobs inside a ring of their overall progress, for the
/// compact and minimal Dynamic Island. Shows the final status once all jobs end.
struct IsoJobCountRing: View {
    let state: IsoJobActivityState

    var body: some View {
        if state.runningCount > 0 {
            ZStack {
                Circle()
                    .stroke(state.tint.opacity(0.25), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: state.overallProgress)
                    .stroke(state.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(state.runningCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(state.tint)
            }
            .frame(width: 22, height: 22)
            .accessibilityLabel("\(state.runningCount) ISO jobs running")
        } else {
            Image(systemName: state.jobs.first?.status.systemImage ?? "checkmark.circle.fill")
                .foregroundStyle(state.tint)
        }
    }
}

// MARK: - Previews

private extension IsoJobActivityJob {
    static let burning = Self(
        id: "preview-burn",
        kind: .burn,
        title: "Family Photos 2024",
        hostName: "studio-mac",
        status: .running,
        progress: 0.42,
        doneCount: 1,
        totalCount: 3,
        doneBytes: 5_905_580_032,
        totalBytes: 14_092_861_440
    )

    static let waitingForDisc = Self(
        id: "preview-burn-waiting",
        kind: .burn,
        title: "Tax Records",
        hostName: "studio-mac",
        status: .running,
        progress: 0.66,
        doneCount: 2,
        totalCount: 3,
        doneBytes: 9_395_240_960,
        totalBytes: 14_092_861_440,
        message: "Insert a blank disc into drive 1"
    )

    static let uploading = Self(
        id: "preview-upload",
        kind: .upload,
        title: "Camera roll backup",
        status: .running,
        progress: 0.18,
        doneCount: 42,
        totalCount: 230,
        doneBytes: 1_288_490_188,
        totalBytes: 7_158_278_826
    )

    static let generating = Self(
        id: "preview-generate",
        kind: .generate,
        title: "Archive 2019–2023",
        hostName: "nas",
        status: .running,
        progress: 0.87,
        doneCount: 6,
        totalCount: 7,
        doneBytes: 28_991_029_248,
        totalBytes: 32_212_254_720
    )

    static let completed = Self(
        id: "preview-completed",
        kind: .burn,
        title: "Family Photos 2024",
        hostName: "studio-mac",
        status: .completed,
        progress: 1,
        doneCount: 3,
        totalCount: 3,
        doneBytes: 14_092_861_440,
        totalBytes: 14_092_861_440
    )

    static let failed = Self(
        id: "preview-failed",
        kind: .burn,
        title: "Family Photos 2024",
        hostName: "studio-mac",
        status: .failed,
        progress: 0.3,
        doneCount: 1,
        totalCount: 3,
        doneBytes: 4_227_858_432,
        totalBytes: 14_092_861_440,
        error: "Verification failed on drive 1"
    )
}

private extension IsoJobActivityState {
    static let oneJob = Self(jobs: [.burning], runningCount: 1)
    static let oneJobWaiting = Self(jobs: [.waitingForDisc], runningCount: 1)
    static let twoJobs = Self(jobs: [.burning, .uploading], runningCount: 2)
    static let threeJobs = Self(jobs: [.burning, .waitingForDisc, .generating], runningCount: 3)
    static let fiveJobs = Self(jobs: [.burning, .waitingForDisc, .generating], runningCount: 5)
    static let endedCompleted = Self(jobs: [.completed], runningCount: 0)
    static let endedFailed = Self(jobs: [.failed], runningCount: 0)
}

#Preview("Lock Screen", as: .content, using: IsoJobActivityAttributes()) {
    IsoJobLiveActivity()
} contentStates: {
    IsoJobActivityState.oneJob
    IsoJobActivityState.oneJobWaiting
    IsoJobActivityState.twoJobs
    IsoJobActivityState.threeJobs
    IsoJobActivityState.fiveJobs
    IsoJobActivityState.endedCompleted
    IsoJobActivityState.endedFailed
}

#Preview("Dynamic Island – Expanded", as: .dynamicIsland(.expanded), using: IsoJobActivityAttributes()) {
    IsoJobLiveActivity()
} contentStates: {
    IsoJobActivityState.oneJob
    IsoJobActivityState.twoJobs
    IsoJobActivityState.threeJobs
    IsoJobActivityState.fiveJobs
    IsoJobActivityState.endedFailed
}

#Preview("Dynamic Island – Compact", as: .dynamicIsland(.compact), using: IsoJobActivityAttributes()) {
    IsoJobLiveActivity()
} contentStates: {
    IsoJobActivityState.oneJob
    IsoJobActivityState.threeJobs
    IsoJobActivityState.fiveJobs
    IsoJobActivityState.endedCompleted
    IsoJobActivityState.endedFailed
}

#Preview("Dynamic Island – Minimal", as: .dynamicIsland(.minimal), using: IsoJobActivityAttributes()) {
    IsoJobLiveActivity()
} contentStates: {
    IsoJobActivityState.oneJob
    IsoJobActivityState.fiveJobs
    IsoJobActivityState.endedCompleted
}
