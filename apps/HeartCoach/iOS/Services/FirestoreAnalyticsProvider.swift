// FirestoreAnalyticsProvider.swift
// Thump iOS
//
// Implements the AnalyticsProvider protocol to route general
// analytics events (screen views, sign-in, nudge completions)
// to a Firestore sub-collection under the user's hashed ID.
// Platforms: iOS 17+

import Foundation
import FirebaseFirestore

// MARK: - Firestore Analytics Provider

/// Routes general analytics events to Firestore.
///
/// Events are stored under `users/{hashedUserId}/events/{autoId}`
/// with a server timestamp for ordering. This provider is registered
/// with the shared ``Analytics`` instance at app startup.
///
/// Respects the same consent and user-ID gating as
/// ``EngineTelemetryService`` to avoid uploading without permission.
struct FirestoreAnalyticsProvider: AnalyticsProvider {

    /// Tracks an analytics event by writing it to Firestore.
    ///
    /// - Parameter event: The event to track.
    func track(event: AnalyticsEvent) {
        let telemetry = EngineTelemetryService.shared

        guard telemetry.isUploadEnabled,
              let userId = telemetry.hashedUserId else {
            return
        }

        var data: [String: Any] = [
            "event": event.name,
            "timestamp": FieldValue.serverTimestamp()
        ]

        // Merge event properties into the document
        for (key, value) in event.properties {
            data[key] = value
        }

        Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("events")
            .addDocument(data: data) { error in
                if let error {
                    AppLogger.engine.debug("[FirestoreAnalytics] Event upload failed: \(error.localizedDescription)")
                }
            }
    }
}
