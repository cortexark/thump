// WatchFeedbackBridge.swift
// ThumpCore
//
// Shared bridge between watch feedback ingestion and the assessment pipeline.
// Platforms: iOS 17+, watchOS 10+, macOS 14+

import Foundation
import Combine

final class WatchFeedbackBridge: ObservableObject {

    @Published var pendingFeedback: [WatchFeedbackPayload] = []

    private var processedEventIds: Set<String> = []
    private let maxPendingCount: Int = 50

    func processFeedback(_ payload: WatchFeedbackPayload) {
        guard !processedEventIds.contains(payload.eventId) else {
            debugPrint("[WatchFeedbackBridge] Duplicate feedback ignored: \(payload.eventId)")
            return
        }

        processedEventIds.insert(payload.eventId)
        pendingFeedback.append(payload)
        pendingFeedback.sort { $0.date < $1.date }

        if pendingFeedback.count > maxPendingCount {
            let excess = pendingFeedback.count - maxPendingCount
            pendingFeedback.removeFirst(excess)
        }
    }

    func latestFeedback() -> DailyFeedback? {
        pendingFeedback.last?.response
    }

    func clearProcessed() {
        pendingFeedback.removeAll()
    }

    var totalProcessedCount: Int {
        processedEventIds.count
    }

    func resetAll() {
        pendingFeedback.removeAll()
        processedEventIds.removeAll()
    }
}
