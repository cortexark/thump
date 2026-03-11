// DashboardViewModel.swift
// Thump iOS
//
// Main dashboard view model. Orchestrates HealthKit data fetching,
// trend engine assessment, local persistence, and nudge tracking.
// Bridges HealthKitService and LocalStore to provide the dashboard
// view with all required state.
// Platforms: iOS 17+

import Foundation
import Combine

// MARK: - Dashboard View Model

/// View model for the primary dashboard screen.
///
/// Coordinates data flow between `HealthKitService`, `HeartTrendEngine`,
/// and `LocalStore` to produce today's `HeartAssessment` and snapshot.
/// Exposes user profile information and nudge completion tracking.
@MainActor
final class DashboardViewModel: ObservableObject {

    // MARK: - Published State

    /// Today's computed heart health assessment.
    @Published var assessment: HeartAssessment?

    /// Today's raw health metrics snapshot.
    @Published var todaySnapshot: HeartSnapshot?

    /// Whether a data refresh is in progress.
    @Published var isLoading: Bool = true

    /// Human-readable error message if the last refresh failed.
    @Published var errorMessage: String?

    /// The user's current subscription tier for feature gating.
    @Published var currentTier: SubscriptionTier = .free

    // MARK: - Dependencies

    private var healthDataProvider: any HealthDataProviding
    private var localStore: LocalStore

    // MARK: - Private Properties

    /// Number of historical days to fetch for the trend engine.
    private let historyDays: Int = ConfigService.defaultLookbackWindow

    /// Cancellable subscriptions for observing tier changes.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Creates a new dashboard view model with injected dependencies.
    ///
    /// - Parameters:
    ///   - healthKitService: The HealthKit service for fetching metrics.
    ///   - localStore: The local persistence store for history and profile.
    init(
        healthKitService: any HealthDataProviding = HealthKitService(),
        localStore: LocalStore = LocalStore()
    ) {
        self.healthDataProvider = healthKitService
        self.localStore = localStore

        bindToLocalStore(localStore)
    }

    // MARK: - Public API

    func bind(
        healthDataProvider: any HealthDataProviding,
        localStore: LocalStore
    ) {
        self.healthDataProvider = healthDataProvider
        self.localStore = localStore
        bindToLocalStore(localStore)
    }

    /// Refreshes the dashboard by fetching today's snapshot, loading
    /// history, running the trend engine, and persisting the result.
    ///
    /// This is the primary data flow method called on appearance and
    /// pull-to-refresh. Errors are caught and surfaced via `errorMessage`.
    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            // Ensure HealthKit authorization
            if !healthDataProvider.isAuthorized {
                try await healthDataProvider.requestAuthorization()
            }

            // Fetch today's snapshot from HealthKit
            let snapshot = try await healthDataProvider.fetchTodaySnapshot()
            todaySnapshot = snapshot

            // Fetch historical snapshots from HealthKit
            let history = try await healthDataProvider.fetchHistory(days: historyDays)

            // Load any persisted feedback for today
            let feedbackPayload = localStore.loadLastFeedback()
            let feedback: DailyFeedback?
            if let feedbackPayload,
               Calendar.current.isDate(
                feedbackPayload.date,
                inSameDayAs: snapshot.date
               ) {
                feedback = feedbackPayload.response
            } else {
                feedback = nil
            }

            // Run the trend engine
            let engine = ConfigService.makeDefaultEngine()
            let result = engine.assess(
                history: history,
                current: snapshot,
                feedback: feedback
            )

            assessment = result

            // Persist the snapshot and assessment
            let stored = StoredSnapshot(snapshot: snapshot, assessment: result)
            localStore.appendSnapshot(stored)

            // Update streak
            updateStreak()

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// Marks today's nudge as completed and updates the local store.
    ///
    /// Increments the streak counter and persists the profile.
    func markNudgeComplete() {
        // Record completion by saving feedback
        let completionPayload = WatchFeedbackPayload(
            date: Date(),
            response: .positive,
            source: "iOS-nudgeComplete"
        )
        localStore.saveLastFeedback(completionPayload)

        // Increment streak
        localStore.profile.streakDays += 1
        localStore.saveProfile()
    }

    // MARK: - Profile Accessors

    /// The user's display name from the profile.
    var profileName: String {
        localStore.profile.displayName
    }

    /// The user's current streak count from the profile.
    var profileStreakDays: Int {
        localStore.profile.streakDays
    }

    // MARK: - Private Helpers

    /// Updates the streak counter based on last check-in date.
    ///
    /// If the user checked in yesterday, the streak continues.
    /// If they missed a day, it resets to 1 (for today's check-in).
    private func updateStreak() {
        let history = localStore.loadHistory()
        guard history.count >= 2 else {
            localStore.profile.streakDays = max(localStore.profile.streakDays, 1)
            localStore.saveProfile()
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastSnapshotDate = history[history.count - 2].snapshot.date
        let lastDay = calendar.startOfDay(for: lastSnapshotDate)

        if let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day,
           daysBetween == 1 {
            // Consecutive day; streak continues (already incremented if nudge completed)
            if localStore.profile.streakDays == 0 {
                localStore.profile.streakDays = 2
                localStore.saveProfile()
            }
        } else if let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day,
                  daysBetween > 1 {
            // Missed a day; reset streak
            localStore.profile.streakDays = 1
            localStore.saveProfile()
        }
    }

    private func bindToLocalStore(_ localStore: LocalStore) {
        currentTier = localStore.tier
        cancellables.removeAll()

        localStore.$tier
            .receive(on: RunLoop.main)
            .sink { [weak self] newTier in
                self?.currentTier = newTier
            }
            .store(in: &cancellables)
    }
}
