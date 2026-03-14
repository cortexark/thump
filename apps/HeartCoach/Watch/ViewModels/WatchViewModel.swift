// WatchViewModel.swift
// Thump Watch
//
// Watch-side view model that bridges the WatchConnectivityService with
// the SwiftUI layer. Manages assessment state, feedback submission,
// and nudge completion tracking.
// Platforms: watchOS 10+

import Foundation
import Combine
import SwiftUI

// MARK: - Sync State

/// Represents the current state of the watch → iPhone sync pipeline.
enum WatchSyncState: Equatable {
    /// Waiting for session activation or initial request.
    case waiting
    /// Phone is paired but currently not reachable (out of range / Bluetooth off).
    case phoneUnreachable
    /// A request is in-flight.
    case syncing
    /// Assessment received successfully.
    case ready
    /// Sync failed with an error message.
    case failed(String)
}

// MARK: - Watch View Model

/// The primary view model for the watch interface. Observes assessment
/// updates from `WatchConnectivityService` via Combine and exposes
/// actions for feedback submission, nudge completion, and manual sync.
@MainActor
final class WatchViewModel: ObservableObject {

    // MARK: - Published State

    /// The most recent assessment received from the companion phone app.
    @Published var latestAssessment: HeartAssessment?

    /// Current state of the sync pipeline — drives the placeholder UI.
    @Published private(set) var syncState: WatchSyncState = .waiting

    /// Whether the user has submitted feedback for the current session.
    @Published var feedbackSubmitted: Bool = false

    /// The type of feedback submitted for the current session, if any.
    /// Used by the view to determine which icon (thumbs-up or thumbs-down) should fill.
    @Published var submittedFeedbackType: DailyFeedback?

    /// Whether the user has marked the current nudge as complete.
    @Published var nudgeCompleted: Bool = false

    /// The latest action plan received from the companion phone app.
    /// Drives the daily / weekly / monthly buddy recommendation screens.
    @Published var latestActionPlan: WatchActionPlan?

    /// IDs of action plan items the user has completed today.
    /// Resets on new day (same as nudgeCompleted).
    @Published private(set) var completedItemIDs: Set<UUID> = []

    // MARK: - Dependencies

    /// Reference to the connectivity service, set via `bind(to:)`.
    /// Kept as a weak-optional to avoid retain cycles with @StateObject ownership.
    private(set) var connectivityService: WatchConnectivityService?

    /// Local feedback persistence service.
    private let feedbackService = WatchFeedbackService()

    // MARK: - Nudge Date Tracking

    /// The date when the nudge was last marked complete.
    /// Used to avoid resetting `nudgeCompleted` within the same day.
    private var lastNudgeCompletionDate: Date?

    // MARK: - Combine

    /// Cancellable subscriptions for connectivity observation.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {}

    // MARK: - Binding

    /// Binds this view model to the given connectivity service.
    ///
    /// Subscribes to the service's `latestAssessment` publisher so that
    /// UI updates automatically whenever a new assessment arrives from
    /// the phone. This method is idempotent; subsequent calls replace
    /// the previous subscription.
    ///
    /// - Parameter service: The `WatchConnectivityService` instance to observe.
    func bind(to service: WatchConnectivityService) {
        self.connectivityService = service

        // Cancel any existing subscriptions before re-binding.
        cancellables.removeAll()

        // Restore today's feedback state from local persistence BEFORE
        // subscribing to publishers, so incoming assessment updates that
        // trigger resetSessionStateIfNeeded() see the correct local state.
        if let savedFeedback = feedbackService.loadFeedback(for: Date()) {
            feedbackSubmitted = true
            submittedFeedbackType = savedFeedback
        }

        // Assessment received → move to ready.
        service.$latestAssessment
            .sink { [weak self] assessment in
                guard let assessment else { return }
                Task { @MainActor [weak self] in
                    self?.latestAssessment = assessment
                    self?.syncState = .ready
                    self?.resetSessionStateIfNeeded()
                    self?.updateComplication(assessment)
                }
            }
            .store(in: &cancellables)

        // Connection error → move to failed.
        service.$connectionError
            .compactMap { $0 }
            .sink { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.syncState = .failed(error)
                }
            }
            .store(in: &cancellables)

        // Reachability changes → update state when no assessment yet.
        service.$isPhoneReachable
            .sink { [weak self] reachable in
                Task { @MainActor [weak self] in
                    guard let self, self.latestAssessment == nil else { return }
                    self.syncState = reachable ? .syncing : .phoneUnreachable
                }
            }
            .store(in: &cancellables)

        // Action plan received → update local copy.
        service.$latestActionPlan
            .sink { [weak self] plan in
                guard let plan else { return }
                Task { @MainActor [weak self] in
                    self?.latestActionPlan = plan
                }
            }
            .store(in: &cancellables)

    }

    // MARK: - Feedback Submission

    /// Submits a daily feedback response, persisting it locally and
    /// forwarding it to the phone via the connectivity service.
    ///
    /// - Parameter response: The user's feedback for the current nudge.
    func submitFeedback(_ response: DailyFeedback) {
        guard !feedbackSubmitted else { return }

        // Persist locally on the watch.
        feedbackService.saveFeedback(response, for: Date())

        // Forward to the phone.
        connectivityService?.sendFeedback(response)

        // Update UI state.
        feedbackSubmitted = true
        submittedFeedbackType = response
    }

    // MARK: - Nudge Completion

    /// Marks the current nudge as complete. This is a local-only state
    /// change; the phone will be notified on the next sync cycle.
    func markNudgeComplete() {
        guard !nudgeCompleted else { return }
        nudgeCompleted = true
        lastNudgeCompletionDate = Date()
    }

    /// Marks a specific action plan item as complete.
    func markItemComplete(_ id: UUID) {
        completedItemIDs.insert(id)
    }

    /// Whether a specific action plan item has been completed.
    func isItemComplete(_ id: UUID) -> Bool {
        completedItemIDs.contains(id)
    }

    /// Today's action items, ordered by reminder hour (earliest first).
    /// Falls back to dailyNudges from the assessment if no action plan exists.
    var todayItems: [DayPlanItem] {
        if let plan = latestActionPlan {
            return plan.dailyItems
                .sorted { ($0.reminderHour ?? 0) < ($1.reminderHour ?? 0) }
                .map { item in
                    DayPlanItem(
                        id: item.id,
                        icon: item.icon,
                        title: item.title,
                        category: item.category,
                        isComplete: completedItemIDs.contains(item.id)
                    )
                }
        }
        // Fallback: use dailyNudges from assessment
        guard let assessment = latestAssessment else { return [] }
        return assessment.dailyNudges.enumerated().map { index, nudge in
            let fakeID = UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", index))") ?? UUID()
            return DayPlanItem(
                id: fakeID,
                icon: nudge.icon,
                title: nudge.title,
                category: nudge.category,
                isComplete: completedItemIDs.contains(fakeID)
            )
        }
    }

    /// The next uncompleted item from today's plan, if any.
    var nextItem: DayPlanItem? {
        todayItems.first { !$0.isComplete }
    }

    // MARK: - Sync

    /// Manually requests the latest assessment from the companion phone app.
    func sync() {
        syncState = .syncing
        connectivityService?.requestLatestAssessment()
    }

    // MARK: - Private Helpers

    /// Pushes current assessment data to shared UserDefaults so the
    /// watch face complication and Smart Stack widget can display it.
    private func updateComplication(_ assessment: HeartAssessment) {
        let mood = BuddyMood.from(assessment: assessment, nudgeCompleted: nudgeCompleted)
        ThumpComplicationData.update(
            mood: mood,
            cardioScore: assessment.cardioScore,
            nudgeTitle: assessment.dailyNudge.title,
            nudgeIcon: assessment.dailyNudge.icon,
            stressFlag: assessment.stressFlag,
            status: assessment.status
        )

        // Push stress heatmap data for the widget
        updateStressHeatmapWidget(assessment)

        // Push readiness score
        let readiness = assessment.cardioScore ?? 70
        ThumpComplicationData.updateReadiness(score: readiness)

        // Push coaching nudge
        let nudgeText: String
        if let mins = assessment.dailyNudge.durationMinutes {
            nudgeText = "\(assessment.dailyNudge.title) · \(mins) min"
        } else {
            nudgeText = assessment.dailyNudge.title
        }
        ThumpComplicationData.updateCoachingNudge(text: nudgeText, icon: assessment.dailyNudge.icon)
    }

    /// Derives 6 hourly stress levels from the assessment and anomaly score,
    /// then pushes them to the stress heatmap widget.
    private func updateStressHeatmapWidget(_ assessment: HeartAssessment) {
        // Derive a base stress level from the anomaly score (0-1 scale)
        // and stress flag, then create a realistic 6-hour spread
        let baseLevel = assessment.stressFlag
            ? min(1.0, 0.5 + assessment.anomalyScore * 0.5)
            : min(0.5, assessment.anomalyScore * 0.6)

        // Generate 6 hourly values with circadian variation
        // Earlier hours slightly lower, recent hours closer to current state
        let levels: [Double] = (0..<6).map { i in
            let ramp = Double(i) / 5.0  // 0.0 → 1.0 over 6 hours
            let circadian = sin(Double(i) * 0.8) * 0.1  // gentle wave
            let level = baseLevel * (0.6 + ramp * 0.4) + circadian
            return min(1.0, max(0.0, level))
        }

        let label = assessment.stressFlag ? "Stress is up" : "Calm today"
        ThumpComplicationData.updateStressHeatmap(
            hourlyLevels: levels,
            label: label,
            isStressed: assessment.stressFlag
        )
    }

    /// Resets session-specific state (feedback submitted, nudge completed)
    /// when a new assessment arrives that likely represents a new day.
    private func resetSessionStateIfNeeded() {
        // If today's feedback has not been recorded locally, reset the flag.
        if !feedbackService.hasFeedbackToday() {
            feedbackSubmitted = false
            submittedFeedbackType = nil
        }
        // Only reset nudge completion when the date changes (new day),
        // not on every assessment received.
        if !Calendar.current.isDateInToday(lastNudgeCompletionDate ?? .distantPast) {
            nudgeCompleted = false
            completedItemIDs.removeAll()
        }
    }
}

// MARK: - Day Plan Item

/// A simplified view-layer representation of a daily action item.
/// Used by the watch face to display today's plan.
struct DayPlanItem: Identifiable {
    let id: UUID
    let icon: String
    let title: String
    let category: NudgeCategory
    let isComplete: Bool
}
