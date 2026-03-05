// WatchFeedbackBridge.swift
// Thump iOS
//
// Bridge between ConnectivityService and the assessment pipeline.
// Receives WatchFeedbackPayload messages from the watch, deduplicates
// them by eventId, and provides the latest feedback for the next
// assessment cycle.
// Platforms: iOS 17+

import Foundation
import Combine

// MARK: - Watch Feedback Bridge

/// Bridges watch feedback from `ConnectivityService` into the assessment pipeline.
///
/// Manages a queue of pending `WatchFeedbackPayload` items received from
/// the watch, deduplicates by `eventId`, and exposes the most recent
/// feedback for incorporation into the next `HeartTrendEngine` assessment.
final class WatchFeedbackBridge: ObservableObject {

    // MARK: - Published State

    /// Pending feedback payloads that have not yet been processed by the engine.
    @Published var pendingFeedback: [WatchFeedbackPayload] = []

    // MARK: - Private Properties

    /// Set of event IDs already seen, used for deduplication.
    private var processedEventIds: Set<String> = []

    /// Maximum number of pending items to retain before auto-pruning old entries.
    private let maxPendingCount: Int = 50

    // MARK: - Initialization

    init() {}

    // MARK: - Public API

    /// Processes an incoming feedback payload from the watch.
    ///
    /// Deduplicates by `eventId` to prevent the same feedback from being
    /// applied multiple times. Adds valid, unique payloads to the pending
    /// queue ordered by date (newest last).
    ///
    /// - Parameter payload: The `WatchFeedbackPayload` received from the watch.
    func processFeedback(_ payload: WatchFeedbackPayload) {
        // Deduplicate by eventId
        guard !processedEventIds.contains(payload.eventId) else {
            debugPrint("[WatchFeedbackBridge] Duplicate feedback ignored: \(payload.eventId)")
            return
        }

        processedEventIds.insert(payload.eventId)
        pendingFeedback.append(payload)

        // Sort by date ascending so most recent is last
        pendingFeedback.sort { $0.date < $1.date }

        // Prune if we exceed the max pending count
        if pendingFeedback.count > maxPendingCount {
            let excess = pendingFeedback.count - maxPendingCount
            pendingFeedback.removeFirst(excess)
        }

        debugPrint("[WatchFeedbackBridge] Processed feedback: \(payload.eventId) (\(payload.response.rawValue))")
    }

    /// Returns the most recent feedback response, or `nil` if no pending feedback exists.
    ///
    /// This is the primary interface for the assessment pipeline. The engine
    /// calls this to incorporate the user's latest daily feedback into the
    /// nudge selection logic.
    ///
    /// - Returns: The `DailyFeedback` response from the most recent pending payload.
    func latestFeedback() -> DailyFeedback? {
        return pendingFeedback.last?.response
    }

    /// Clears all processed feedback from the pending queue.
    ///
    /// Called after the assessment pipeline has consumed the feedback,
    /// resetting the bridge for the next cycle. Retains the deduplication
    /// set to prevent reprocessing of already-seen event IDs.
    func clearProcessed() {
        pendingFeedback.removeAll()
        debugPrint("[WatchFeedbackBridge] Cleared \(pendingFeedback.count) pending feedback items.")
    }

    // MARK: - Diagnostic Helpers

    /// Returns the count of unique event IDs that have been processed
    /// since the bridge was created (or last reset).
    var totalProcessedCount: Int {
        processedEventIds.count
    }

    /// Fully resets the bridge, clearing both pending items and the
    /// deduplication history. Use sparingly (e.g., on sign-out).
    func resetAll() {
        pendingFeedback.removeAll()
        processedEventIds.removeAll()
        debugPrint("[WatchFeedbackBridge] Full reset completed.")
    }
}
