//
//  IsoJobListView.swift
//  RxStorage
//
//  List of ISO generation and burning jobs synced from iso-burner
//

import RxStorageCore
import SwiftUI

/// ISO job list view
struct IsoJobListView: View {
    @Binding var selectedJob: IsoJob?
    let horizontalSizeClass: UserInterfaceSizeClass

    @State private var viewModel = IsoJobListViewModel()
    @State private var errorViewModel = ErrorViewModel()
    @Environment(EventViewModel.self) private var eventViewModel

    // Delete confirmation state
    @State private var jobToDelete: IsoJob?
    @State private var showDeleteConfirmation = false

    /// Initialize with an optional binding (defaults to constant nil for standalone use)
    init(horizontalSizeClass: UserInterfaceSizeClass, selectedJob: Binding<IsoJob?> = .constant(nil)) {
        self.horizontalSizeClass = horizontalSizeClass
        _selectedJob = selectedJob
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.jobs.isEmpty {
                ProgressView("Loading ISO jobs...")
            } else if viewModel.jobs.isEmpty {
                ContentUnavailableView(
                    "No ISO Jobs",
                    systemImage: "opticaldisc",
                    description: Text("Sign in to iso-burner with your RxLab account to follow ISO generation and disc burning here.")
                )
            } else {
                jobsList
            }
        }
        .navigationTitle("ISO Jobs")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                filterMenu
            }
        }
        .refreshable {
            await viewModel.refreshJobs()
        }
        .task {
            await viewModel.fetchJobs()
        }
        .liveRefresh(while: viewModel.hasRunningJobs) {
            await viewModel.refreshJobs()
        }
        .task {
            for await event in eventViewModel.stream {
                if case let .isoJobDeleted(id) = event {
                    if selectedJob?.id == id {
                        selectedJob = nil
                    }
                    await viewModel.refreshJobs()
                }
            }
        }
        .confirmationDialog(
            title: "Delete ISO Job",
            message: "Delete the progress history of \"\(jobToDelete?.title ?? "")\"? The ISO files and discs are not affected.",
            confirmButtonTitle: "Delete",
            isPresented: $showDeleteConfirmation,
            onConfirm: {
                if let job = jobToDelete {
                    Task {
                        do {
                            let deletedId = try await viewModel.deleteJob(job)
                            if selectedJob?.id == deletedId {
                                selectedJob = nil
                            }
                        } catch {
                            errorViewModel.showError(error)
                        }
                        jobToDelete = nil
                    }
                }
            },
            onCancel: { jobToDelete = nil }
        )
        .onChange(of: viewModel.error != nil) { _, hasError in
            if hasError, let error = viewModel.error {
                errorViewModel.showError(error)
                viewModel.clearError()
            }
        }
        .showViewModelError(errorViewModel)
    }

    // MARK: - Filter

    private var filterMenu: some View {
        Menu {
            Picker(
                "Show",
                selection: Binding(
                    get: { viewModel.kindFilter },
                    set: { kind in Task { await viewModel.setKindFilter(kind) } }
                )
            ) {
                Text("All Jobs").tag(IsoJobKind?.none)
                ForEach(IsoJobKind.allCases, id: \.self) { kind in
                    Label(kind.displayName, systemImage: kind.systemImage).tag(IsoJobKind?.some(kind))
                }
            }
        } label: {
            Label(
                "Filter",
                systemImage: viewModel.kindFilter == nil
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .accessibilityIdentifier("iso-jobs-filter")
    }

    // MARK: - Jobs List

    private var jobsList: some View {
        AdaptiveList(horizontalSizeClass: horizontalSizeClass, selection: $selectedJob) {
            ForEach(viewModel.jobs) { job in
                NavigationLink(value: job) {
                    IsoJobRow(job: job)
                }
                #if os(macOS)
                .contextMenu {
                    Button(role: .destructive) {
                        jobToDelete = job
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                #else
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                jobToDelete = job
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                #endif
                        .onAppear {
                            if job.id == viewModel.jobs.last?.id {
                                Task { await viewModel.loadMoreJobs() }
                            }
                        }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
    }
}

/// ISO job row in list
struct IsoJobRow: View {
    let job: IsoJob

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(job.title, systemImage: job.kind.systemImage)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                IsoJobStatusBadge(status: job.status)
            }

            ProgressView(value: min(max(job.progress, 0), 1))
                .tint(job.status.color)

            HStack {
                Text("\(job.doneCount) of \(job.totalCount) \(job.kind.unitName)")
                Spacer()
                Text(IsoJobFormat.percent(job.progress))
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("iso-job-row-\(job.id)")
    }

    private var subtitle: String {
        let updated = "Updated \(job.updatedAt.formatted(.relative(presentation: .named)))"
        if let host = job.hostName, !host.isEmpty {
            return "\(host) · \(updated)"
        }
        return updated
    }
}

#Preview {
    NavigationStack {
        IsoJobListView(horizontalSizeClass: .compact)
    }
    .environment(EventViewModel())
}
