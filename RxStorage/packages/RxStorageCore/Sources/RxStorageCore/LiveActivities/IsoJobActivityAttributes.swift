//
//  IsoJobActivityAttributes.swift
//  RxStorageCore
//
//  Live Activity listing the user's running ISO jobs. The server starts,
//  updates and ends it over APNs, so the field names must match the push
//  payload built in admin/lib/push/iso-job-live-activities.ts.
//

#if canImport(ActivityKit) && os(iOS)
    import ActivityKit

    /// One activity per user, so there are no static attributes; everything
    /// changes as jobs start and end.
    public struct IsoJobActivityAttributes: ActivityAttributes {
        /// Most jobs the server lists; the rest only count towards `runningCount`
        public static let maxListedJobs = 3

        public struct Job: Codable, Hashable, Sendable, Identifiable {
            public var id: String
            public var kind: IsoJobKind
            public var title: String
            /// Machine running the job
            public var hostName: String?
            public var status: IsoJobStatus
            /// Fraction done, 0 to 1
            public var progress: Double
            public var doneCount: Int
            public var totalCount: Int
            public var doneBytes: Int
            public var totalBytes: Int
            /// Current state, e.g. waiting for a disc
            public var message: String?
            /// Why the job failed
            public var error: String?

            public init(
                id: String,
                kind: IsoJobKind,
                title: String,
                hostName: String? = nil,
                status: IsoJobStatus,
                progress: Double,
                doneCount: Int,
                totalCount: Int,
                doneBytes: Int,
                totalBytes: Int,
                message: String? = nil,
                error: String? = nil
            ) {
                self.id = id
                self.kind = kind
                self.title = title
                self.hostName = hostName
                self.status = status
                self.progress = progress
                self.doneCount = doneCount
                self.totalCount = totalCount
                self.doneBytes = doneBytes
                self.totalBytes = totalBytes
                self.message = message
                self.error = error
            }
        }

        public struct ContentState: Codable, Hashable, Sendable {
            /// Up to `maxListedJobs` running jobs, oldest first. Once the last job
            /// ends, holds that job with its final status.
            public var jobs: [Job]
            /// All of the user's running jobs, including ones not listed
            public var runningCount: Int

            public init(jobs: [Job], runningCount: Int) {
                self.jobs = jobs
                self.runningCount = runningCount
            }

            /// Running jobs left out of `jobs`
            public var hiddenCount: Int {
                max(runningCount - jobs.count, 0)
            }

            /// Mean progress of the listed jobs, 0 to 1
            public var overallProgress: Double {
                guard !jobs.isEmpty else { return 0 }
                return jobs.map { min(max($0.progress, 0), 1) }.reduce(0, +) / Double(jobs.count)
            }
        }

        public init() {}
    }
#endif
