//
//  IsoJobLiveActivityTests.swift
//  RxStorageCoreTests
//
//  Tests for ISO job Live Activity deep links and push payload decoding
//

import Foundation
@testable import RxStorageCore
import Testing

@Suite("IsoJobDeepLink")
struct IsoJobDeepLinkTests {
    @Test("Round-trips a job ID through the deep link URL")
    func roundTrip() {
        let url = IsoJobDeepLink.url(jobId: "job-123")
        #expect(url.absoluteString == "rxstorage://iso-jobs/job-123")
        #expect(IsoJobDeepLink.jobId(from: url) == "job-123")
    }

    @Test("Ignores other links")
    func ignoresOtherLinks() throws {
        #expect(try IsoJobDeepLink.jobId(from: #require(URL(string: "rxstorage://oauth/callback"))) == nil)
        #expect(try IsoJobDeepLink.jobId(from: #require(URL(string: "https://iso-jobs/job-123"))) == nil)
        #expect(try IsoJobDeepLink.jobId(from: #require(URL(string: "rxstorage://iso-jobs/"))) == nil)
    }
}

#if canImport(ActivityKit) && os(iOS)
    @Suite("IsoJobActivityAttributes")
    struct IsoJobActivityAttributesTests {
        @Test("Decodes the content state pushed by the server")
        func decodesServerPayload() throws {
            // Mirrors buildContentState in admin/lib/push/iso-job-live-activities.ts
            let payload = Data("""
            {"jobs":[{"id":"job-1","kind":"burn","title":"Photos 2024","hostName":null,"status":"running",\
            "progress":0.5,"doneCount":1,"totalCount":2,"doneBytes":100,"totalBytes":200,"message":null,"error":null}],\
            "runningCount":4}
            """.utf8)

            let state = try JSONDecoder().decode(IsoJobActivityAttributes.ContentState.self, from: payload)
            #expect(state.jobs.count == 1)
            #expect(state.jobs[0].kind == .burn)
            #expect(state.jobs[0].status == .running)
            #expect(state.jobs[0].hostName == nil)
            #expect(state.hiddenCount == 3)
            #expect(state.overallProgress == 0.5)

            _ = try JSONDecoder().decode(IsoJobActivityAttributes.self, from: Data("{}".utf8))
        }

        @Test("Builds the content state from running jobs, oldest first")
        func buildsStateFromRunningJobs() {
            func job(_ id: String, status: IsoJobStatus = .running, startedAfter seconds: TimeInterval) -> IsoJob {
                var job = TestHelpers.makeIsoJob(id: id, status: status)
                job.startedAt = job.startedAt.addingTimeInterval(seconds)
                return job
            }

            let state = IsoJobActivityAttributes.ContentState(runningJobs: [
                job("newest", startedAfter: 40),
                job("done", status: .completed, startedAfter: 0),
                job("oldest", startedAfter: 10),
                job("second", startedAfter: 20),
                job("third", startedAfter: 30),
            ])

            #expect(state.jobs.map(\.id) == ["oldest", "second", "third"])
            #expect(state.runningCount == 4)
            #expect(state.hiddenCount == 1)
            #expect(IsoJobActivityAttributes.ContentState(runningJobs: []).runningCount == 0)
        }

        @Test("Ends with the ended job and nothing running, like the server's end push")
        func buildsEndedState() {
            let job = IsoJobActivityAttributes.Job(job: TestHelpers.makeIsoJob(id: "job-1", status: .completed))
            let state = IsoJobActivityAttributes.ContentState(endedJob: job)

            #expect(state.jobs == [job])
            #expect(state.jobs[0].status == .completed)
            #expect(state.runningCount == 0)
            #expect(state.hiddenCount == 0)
        }
    }
#endif
