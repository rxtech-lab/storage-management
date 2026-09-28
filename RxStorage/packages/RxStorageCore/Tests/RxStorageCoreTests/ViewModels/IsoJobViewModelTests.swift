//
//  IsoJobViewModelTests.swift
//  RxStorageCoreTests
//
//  Tests for IsoJobListViewModel and IsoJobDetailViewModel
//

@testable import RxStorageCore
import Testing

@Suite("IsoJobListViewModel Tests")
struct IsoJobListViewModelTests {
    @Test("Fetch jobs and report running state")
    @MainActor
    func fetchJobs() async {
        let service = MockIsoJobService()
        service.fetchJobsPaginatedResults = [.success(TestHelpers.page([
            TestHelpers.makeIsoJob(id: "a", status: .running),
            TestHelpers.makeIsoJob(id: "b", status: .completed),
        ]))]
        let sut = IsoJobListViewModel(isoJobService: service)

        await sut.fetchJobs()

        #expect(sut.jobs.map(\.id) == ["a", "b"])
        #expect(sut.totalCount == 2)
        #expect(sut.hasRunningJobs)
        #expect(sut.isLoading == false)
        #expect(sut.error == nil)
    }

    @Test("Fetch jobs with error")
    @MainActor
    func fetchJobsError() async {
        let service = MockIsoJobService()
        service.fetchJobsPaginatedResults = [.failure(APIError.serverError("boom"))]
        let sut = IsoJobListViewModel(isoJobService: service)

        await sut.fetchJobs()

        #expect(sut.jobs.isEmpty)
        #expect(sut.error != nil)
        #expect(sut.hasRunningJobs == false)
    }

    @Test("Load more appends the next page without duplicates")
    @MainActor
    func loadMore() async {
        let service = MockIsoJobService()
        service.fetchJobsPaginatedResults = [
            .success(TestHelpers.page([TestHelpers.makeIsoJob(id: "a")], nextCursor: "c1", total: 3)),
            .success(TestHelpers.page([TestHelpers.makeIsoJob(id: "a"), TestHelpers.makeIsoJob(id: "b")], total: 3)),
        ]
        let sut = IsoJobListViewModel(isoJobService: service)

        await sut.fetchJobs()
        await sut.loadMoreJobs()

        #expect(sut.jobs.map(\.id) == ["a", "b"])
        #expect(sut.hasNextPage == false)
        #expect(service.fetchJobsFilters.last??.cursor == "c1")

        // No further page is requested once exhausted.
        await sut.loadMoreJobs()
        #expect(service.fetchJobsFilters.count == 2)
    }

    @Test("Kind filter is sent and reloads the list")
    @MainActor
    func kindFilter() async {
        let service = MockIsoJobService()
        service.fetchJobsPaginatedResults = [
            .success(TestHelpers.page([TestHelpers.makeIsoJob(id: "a", kind: .burn)])),
        ]
        let sut = IsoJobListViewModel(isoJobService: service)

        await sut.setKindFilter(.burn)

        #expect(sut.kindFilter == .burn)
        #expect(service.fetchJobsFilters.last??.kind == .burn)
        #expect(sut.jobs.map(\.id) == ["a"])
    }

    @Test("Refresh updates progress without a loading state")
    @MainActor
    func refreshJobs() async {
        let service = MockIsoJobService()
        service.fetchJobsPaginatedResults = [
            .success(TestHelpers.page([TestHelpers.makeIsoJob(id: "a", status: .running, progress: 0.2)])),
            .success(TestHelpers.page([TestHelpers.makeIsoJob(id: "a", status: .completed, progress: 1)])),
        ]
        let sut = IsoJobListViewModel(isoJobService: service)

        await sut.fetchJobs()
        await sut.refreshJobs()

        #expect(sut.jobs.first?.progress == 1)
        #expect(sut.hasRunningJobs == false)
    }

    @Test("Delete removes the job")
    @MainActor
    func deleteJob() async throws {
        let service = MockIsoJobService()
        let job = TestHelpers.makeIsoJob(id: "a")
        service.fetchJobsPaginatedResults = [.success(TestHelpers.page([job]))]
        let sut = IsoJobListViewModel(isoJobService: service)
        await sut.fetchJobs()

        let deleted = try await sut.deleteJob(job)

        #expect(deleted == "a")
        #expect(sut.jobs.isEmpty)
        #expect(sut.totalCount == 0)
        #expect(service.deletedJobIds == ["a"])
    }
}

@Suite("IsoJobDetailViewModel Tests")
struct IsoJobDetailViewModelTests {
    @Test("Fetch job splits drive and ISO rows")
    @MainActor
    func fetchJob() async {
        let service = MockIsoJobService()
        service.fetchJobResults = [.success(TestHelpers.makeIsoJobDetail(tasks: [
            TestHelpers.makeIsoJobTask(id: "d1", section: .drive, name: "PIONEER BDR-XD07", status: "burning"),
            TestHelpers.makeIsoJobTask(id: "i1", section: .iso, name: "backup_1.iso", status: "burning"),
            TestHelpers.makeIsoJobTask(id: "i2", section: .iso, name: "backup_2.iso", status: "pending"),
        ]))]
        let sut = IsoJobDetailViewModel(isoJobService: service)

        await sut.fetchJob(id: "job-1")

        #expect(service.fetchJobIds == ["job-1"])
        #expect(sut.isRunning)
        #expect(sut.driveTasks.map(\.id) == ["d1"])
        #expect(sut.isoTasks.map(\.id) == ["i1", "i2"])
        #expect(sut.isLoading == false)
    }

    @Test("Refresh reloads the same job")
    @MainActor
    func refresh() async {
        let service = MockIsoJobService()
        service.fetchJobResults = [
            .success(TestHelpers.makeIsoJobDetail(status: .running)),
            .success(TestHelpers.makeIsoJobDetail(status: .completed)),
        ]
        let sut = IsoJobDetailViewModel(isoJobService: service)

        await sut.fetchJob(id: "job-1")
        await sut.refresh()

        #expect(service.fetchJobIds == ["job-1", "job-1"])
        #expect(sut.job?.status == .completed)
        #expect(sut.isRunning == false)
    }

    @Test("Fetch job error")
    @MainActor
    func fetchJobError() async {
        let service = MockIsoJobService()
        service.fetchJobResults = [.failure(APIError.notFound)]
        let sut = IsoJobDetailViewModel(isoJobService: service)

        await sut.fetchJob(id: "missing")

        #expect(sut.job == nil)
        #expect(sut.error != nil)
    }
}
