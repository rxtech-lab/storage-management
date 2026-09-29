//
//  LiveActivityManager.swift
//  RxStorage
//
//  Hands ActivityKit push tokens to the server so it can start the ISO jobs
//  Live Activity when a job starts, then update and end it as jobs run. While
//  the app is open it also fetches job status itself to refresh the activity.
//

#if os(iOS)
    import ActivityKit
    import os
    import RxStorageCore
    import UIKit

    private let logger = Logger(subsystem: "rxlab.RxStorage", category: "LiveActivities")

    @MainActor
    final class LiveActivityManager {
        static let shared = LiveActivityManager()

        private let service: LiveActivityServiceProtocol
        private let isoJobService: IsoJobServiceProtocol
        private var observers: [Task<Void, Never>] = []
        /// Token observers for running activities, keyed by activity ID
        private var activityObservers: [String: Task<Void, Never>] = [:]

        /// Push-to-start token last registered with the server, kept so it can be removed on sign out
        private static let registeredStartTokenKey = "registeredLiveActivityStartToken"
        /// Update tokens registered with the server, keyed by activity ID, so tokens of
        /// activities that ended while the app was not running can be removed
        private static let registeredUpdateTokensKey = "registeredLiveActivityUpdateTokens"

        init(
            service: LiveActivityServiceProtocol = LiveActivityService(),
            isoJobService: IsoJobServiceProtocol = IsoJobService()
        ) {
            self.service = service
            self.isoJobService = isoJobService
        }

        /// Starts forwarding push tokens to the server. Call while signed in.
        func startObserving() {
            guard observers.isEmpty else { return }

            observers.append(Task { [weak self] in
                for await data in Activity<IsoJobActivityAttributes>.pushToStartTokenUpdates {
                    await self?.registerStartToken(data)
                }
            })

            observers.append(Task { [weak self] in
                await self?.removeEndedActivityTokens()
                // Activities already running, then ones the server starts from now on
                for activity in Activity<IsoJobActivityAttributes>.activities {
                    self?.observeUpdateTokens(of: activity)
                }
                for await activity in Activity<IsoJobActivityAttributes>.activityUpdates {
                    self?.observeUpdateTokens(of: activity)
                }
            })
        }

        /// Fetches job status and refreshes the activity every `refreshInterval` until
        /// the calling task is cancelled. Server pushes are throttled and only sent when
        /// the CLI reports progress, so this keeps the activity current while the app runs.
        /// Call while the app is active and signed in.
        func refreshPeriodically() async {
            while !Task.isCancelled {
                await refreshActivity()
                try? await Task.sleep(for: Self.refreshInterval)
            }
        }

        /// How often `refreshPeriodically` fetches job status
        private static let refreshInterval: Duration = .seconds(10)

        /// How long the activity stays on the Lock Screen after the last job ends,
        /// matching the server's end push
        private static let dismissAfter: TimeInterval = 15 * 60

        /// Brings the activity in line with the user's running jobs: starts it for jobs
        /// that are already running, since the server only starts one when a job starts,
        /// updates it while jobs run, and ends it once none are left. A started activity's
        /// update token is registered through `activityUpdates`, so the server keeps it
        /// up to date too.
        func refreshActivity() async {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

            let jobs: [IsoJob]
            do {
                jobs = try await isoJobService.fetchJobsPaginated(
                    filters: IsoJobFilters(status: .running, limit: 100)
                ).data
            } catch {
                logger.error("Failed to fetch running ISO jobs: \(error.localizedDescription)")
                return
            }

            let state = IsoJobActivityAttributes.ContentState(runningJobs: jobs)
            // Read after the fetch, which may have raced with a push-to-start activity
            let activities = Self.liveActivities

            if activities.isEmpty {
                guard state.runningCount > 0 else { return }
                do {
                    _ = try Activity.request(
                        attributes: IsoJobActivityAttributes(),
                        content: ActivityContent(state: state, staleDate: nil),
                        pushType: .token
                    )
                } catch {
                    logger.error("Failed to start ISO jobs Live Activity: \(error.localizedDescription)")
                }
                return
            }

            if state.runningCount > 0 {
                for activity in activities where activity.content.state != state {
                    await activity.update(ActivityContent(state: state, staleDate: nil))
                }
                return
            }

            // The last jobs ended: show how one of them ended, then let the activity go
            for activity in activities {
                let finalState = await endedState(of: activity.content.state)
                await activity.end(
                    ActivityContent(state: finalState, staleDate: nil),
                    dismissalPolicy: .after(Date().addingTimeInterval(Self.dismissAfter))
                )
            }
        }

        /// Activities still running; ended ones may linger on the Lock Screen
        private static var liveActivities: [Activity<IsoJobActivityAttributes>] {
            Activity<IsoJobActivityAttributes>.activities.filter {
                $0.activityState == .active || $0.activityState == .stale
            }
        }

        /// The state to end with once nothing is running: the first listed job with
        /// its final status, or the last known state if that job cannot be fetched
        private func endedState(
            of state: IsoJobActivityAttributes.ContentState
        ) async -> IsoJobActivityAttributes.ContentState {
            guard let job = state.jobs.first else {
                return IsoJobActivityAttributes.ContentState(jobs: [], runningCount: 0)
            }
            do {
                let detail = try await isoJobService.fetchJob(id: job.id)
                return IsoJobActivityAttributes.ContentState(endedJob: .init(job: detail))
            } catch {
                logger.error("Failed to fetch ended ISO job \(job.id): \(error.localizedDescription)")
                return IsoJobActivityAttributes.ContentState(endedJob: job)
            }
        }

        /// Stops Live Activity pushes to this device and removes its activities.
        /// Call before signing out, while the session is still valid.
        func stop() async {
            observers.forEach { $0.cancel() }
            observers.removeAll()
            activityObservers.values.forEach { $0.cancel() }
            activityObservers.removeAll()

            for activity in Activity<IsoJobActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            var tokens = Array(updateTokens.values)
            if let startToken = UserDefaults.standard.string(forKey: Self.registeredStartTokenKey) {
                tokens.append(startToken)
            }
            for token in tokens {
                await unregister(token: token)
            }
            UserDefaults.standard.removeObject(forKey: Self.registeredStartTokenKey)
            updateTokens = [:]
        }

        private func observeUpdateTokens(of activity: Activity<IsoJobActivityAttributes>) {
            guard activityObservers[activity.id] == nil else { return }

            activityObservers[activity.id] = Task { [weak self] in
                // Ends when the activity ends
                for await data in activity.pushTokenUpdates {
                    guard let self, let token = await register(token: data, kind: .update) else { continue }
                    updateTokens[activity.id] = token
                }
                guard let self, !Task.isCancelled else { return }
                activityObservers[activity.id] = nil
                await removeToken(ofActivity: activity.id)
            }
        }

        /// Unregisters update tokens of activities that are no longer running, e.g.
        /// ones the user dismissed, so the server starts a new activity for the next job
        private func removeEndedActivityTokens() async {
            let running = Set(Activity<IsoJobActivityAttributes>.activities.map(\.id))
            for activityId in updateTokens.keys where !running.contains(activityId) {
                await removeToken(ofActivity: activityId)
            }
        }

        private func removeToken(ofActivity activityId: String) async {
            guard let token = updateTokens[activityId] else { return }
            await unregister(token: token)
            updateTokens[activityId] = nil
        }

        private var updateTokens: [String: String] {
            get {
                UserDefaults.standard.dictionary(forKey: Self.registeredUpdateTokensKey) as? [String: String] ?? [:]
            }
            set {
                UserDefaults.standard.set(newValue, forKey: Self.registeredUpdateTokensKey)
            }
        }

        private func registerStartToken(_ data: Data) async {
            guard let token = await register(token: data, kind: .start) else { return }
            UserDefaults.standard.set(token, forKey: Self.registeredStartTokenKey)
        }

        private func register(token data: Data, kind: LiveActivityTokenKind) async -> String? {
            let token = data.map { String(format: "%02x", $0) }.joined()

            // The app may only be woken briefly to deliver a new activity's token
            let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "RegisterLiveActivityToken")
            defer { UIApplication.shared.endBackgroundTask(backgroundTask) }

            do {
                _ = try await service.registerToken(
                    LiveActivityTokenRegisterRequest(
                        token: token,
                        kind: kind,
                        environment: PushNotificationManager.environment
                    )
                )
                return token
            } catch {
                logger.error("Failed to register Live Activity \(kind.rawValue) token: \(error.localizedDescription)")
                return nil
            }
        }

        private func unregister(token: String) async {
            do {
                try await service.unregisterToken(token: token)
            } catch {
                logger.error("Failed to unregister Live Activity token: \(error.localizedDescription)")
            }
        }
    }
#endif
