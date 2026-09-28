//
//  IsoJobDetailView.swift
//  RxStorage
//
//  Live progress of one ISO generation or burning job
//

import RxStorageCore
import SwiftUI

/// ISO job detail view
struct IsoJobDetailView: View {
    let jobId: String

    @State private var viewModel = IsoJobDetailViewModel()
    @State private var errorViewModel = ErrorViewModel()
    @State private var showDeleteConfirmation = false
    @Environment(EventViewModel.self) private var eventViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let job = viewModel.job {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(job)
                            .cardStyle()

                        overallProgress(job)
                            .cardStyle()

                        if !viewModel.driveTasks.isEmpty {
                            taskSection("Drives", systemImage: "opticaldiscdrive", tasks: viewModel.driveTasks)
                                .cardStyle()
                        }

                        if !viewModel.isoTasks.isEmpty {
                            taskSection("ISO Files", systemImage: "doc.zipper", tasks: viewModel.isoTasks)
                                .cardStyle()
                        }
                    }
                    .padding()
                }
                .background(Color.systemGroupedBackground)
                .refreshable {
                    await viewModel.refresh()
                }
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    "Error Loading ISO Job",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle(viewModel.job?.title ?? "ISO Job")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                if viewModel.job != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityIdentifier("iso-job-delete")
                    }
                }
            }
            .task(id: jobId) {
                await viewModel.fetchJob(id: jobId)
            }
            .liveRefresh(while: viewModel.isRunning) {
                await viewModel.refresh()
            }
            .confirmationDialog(
                title: "Delete ISO Job",
                message: "Delete the progress history of \"\(viewModel.job?.title ?? "")\"? The ISO files and discs are not affected.",
                confirmButtonTitle: "Delete",
                isPresented: $showDeleteConfirmation,
                onConfirm: {
                    Task {
                        do {
                            try await viewModel.deleteJob()
                            eventViewModel.emit(.isoJobDeleted(id: jobId))
                            dismiss()
                        } catch {
                            errorViewModel.showError(error)
                        }
                    }
                },
                onCancel: {}
            )
            .showViewModelError(errorViewModel)
    }

    // MARK: - Header

    private func header(_ job: IsoJobDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(job.kind.displayName, systemImage: job.kind.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                IsoJobStatusBadge(status: job.status)
            }

            Text(job.title)
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityIdentifier("iso-job-detail-title")

            if let host = job.hostName, !host.isEmpty {
                DetailRow(label: "Computer", value: host, icon: "desktopcomputer")
            }
            DetailRow(
                label: "Started",
                value: job.startedAt.formatted(date: .abbreviated, time: .shortened),
                icon: "calendar"
            )
            if let finishedAt = job.finishedAt {
                DetailRow(
                    label: "Finished",
                    value: finishedAt.formatted(date: .abbreviated, time: .shortened),
                    icon: "flag.checkered"
                )
            }
            DetailRow(
                label: "Last report",
                value: job.updatedAt.formatted(.relative(presentation: .named)),
                icon: "clock"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Overall Progress

    private func overallProgress(_ job: IsoJobDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
                Text(IsoJobFormat.percent(job.progress))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            ProgressView(value: min(max(job.progress, 0), 1))
                .tint(job.status.color)

            HStack {
                Text("\(job.doneCount) of \(job.totalCount) \(job.kind.unitName)")
                Spacer()
                Text("\(IsoJobFormat.bytes(job.doneBytes)) of \(IsoJobFormat.bytes(job.totalBytes))")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let message = job.message, !message.isEmpty {
                Label(message, systemImage: "info.circle")
                    .font(.subheadline)
            }

            if let error = job.error, !error.isEmpty {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Tasks

    private func taskSection(_ title: String, systemImage: String, tasks: [IsoJobTask]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            ForEach(tasks) { task in
                IsoJobTaskRow(task: task)
                if task.id != tasks.last?.id {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One ISO file or drive of an ISO job
struct IsoJobTaskRow: View {
    let task: IsoJobTask

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(task.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                Text("\(task.status.capitalized) · \(IsoJobFormat.percent(task.progress))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressView(value: min(max(task.progress, 0), 1))
                .tint(tint)

            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = task.error, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .accessibilityIdentifier("iso-job-task-\(task.id)")
    }

    private var tint: Color {
        if task.status == "failed" { return .red }
        return task.progress >= 1 ? .green : .accentColor
    }

    private var caption: String? {
        var parts: [String] = []
        if let detail = task.detail, !detail.isEmpty {
            parts.append(detail)
        }
        if task.totalBytes > 0 {
            parts.append("\(IsoJobFormat.bytes(task.doneBytes)) of \(IsoJobFormat.bytes(task.totalBytes))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack {
        IsoJobDetailView(jobId: "1")
    }
    .environment(EventViewModel())
}
