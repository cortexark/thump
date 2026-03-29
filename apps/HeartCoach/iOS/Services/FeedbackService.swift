// FeedbackService.swift
// Thump iOS
//
// Uploads bug reports and feature requests to Firebase Firestore.
// Reports are stored under users/{hashedUserId}/bug-reports/{autoId}
// and users/{hashedUserId}/feature-requests/{autoId}.
// Platforms: iOS 17+

import Foundation
import FirebaseFirestore

// MARK: - Feedback Service

/// Uploads bug reports and feature requests to Firestore so the team
/// can query and triage feedback from the Firebase Console.
final class FeedbackService {

    // MARK: - Singleton

    static let shared = FeedbackService()

    // MARK: - Properties

    private let db = Firestore.firestore()

    // MARK: - Initialization

    private init() {}

    // MARK: - Bug Reports

    /// Uploads a bug report document to Firestore.
    ///
    /// Health metrics are only included when the user explicitly opts in
    /// via the `includeHealthData` parameter (Apple Guideline 5.1.3(i)).
    /// Age and biological sex are never sent — they constitute PHI when
    /// combined with the hashed user ID.
    func submitBugReport(
        description: String,
        appVersion: String,
        deviceModel: String,
        iosVersion: String,
        healthMetrics: [String: Any],
        includeHealthData: Bool,
        completion: ((Error?) -> Void)? = nil
    ) {
        let userId = EngineTelemetryService.shared.hashedUserId ?? "anonymous"

        var data: [String: Any] = [
            "description": description,
            "appVersion": appVersion,
            "deviceModel": deviceModel,
            "iosVersion": iosVersion,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "new"
        ]

        // Only attach health metrics when the user gave explicit consent
        if includeHealthData {
            // Strip any PHI fields that may have been included by the caller
            var sanitized = healthMetrics
            sanitized.removeValue(forKey: "userAge")
            sanitized.removeValue(forKey: "userSex")
            sanitized.removeValue(forKey: "screenshotBase64")
            data["healthMetrics"] = sanitized
            data["healthDataConsentGiven"] = true
        }

        db.collection("users")
            .document(userId)
            .collection("bug-reports")
            .addDocument(data: data) { error in
                if let error {
                    AppLogger.engine.warning("[FeedbackService] Bug report upload failed: \(error.localizedDescription)")
                } else {
                    AppLogger.engine.info("[FeedbackService] Bug report uploaded successfully")
                }
                completion?(error)
            }
    }

    /// Uploads a bug report for testing purposes with a specific user ID.
    func submitTestBugReport(
        userId: String,
        description: String,
        appVersion: String,
        deviceModel: String,
        iosVersion: String,
        healthMetrics: [String: Any] = [:],
        completion: @escaping (Error?) -> Void
    ) {
        var data: [String: Any] = [
            "description": description,
            "appVersion": appVersion,
            "deviceModel": deviceModel,
            "iosVersion": iosVersion,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "new"
        ]
        if !healthMetrics.isEmpty {
            data["healthMetrics"] = healthMetrics
        }

        db.collection("users")
            .document(userId)
            .collection("bug-reports")
            .addDocument(data: data) { error in
                completion(error)
            }
    }

    // MARK: - Feature Requests

    /// Uploads a feature request document to Firestore.
    func submitFeatureRequest(
        description: String,
        appVersion: String
    ) {
        let userId = EngineTelemetryService.shared.hashedUserId ?? "anonymous"

        let data: [String: Any] = [
            "description": description,
            "appVersion": appVersion,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "new"
        ]

        db.collection("users")
            .document(userId)
            .collection("feature-requests")
            .addDocument(data: data) { error in
                if let error {
                    AppLogger.engine.warning("[FeedbackService] Feature request upload failed: \(error.localizedDescription)")
                } else {
                    AppLogger.engine.info("[FeedbackService] Feature request uploaded successfully")
                }
            }
    }

    /// Uploads a feature request for testing purposes with a specific user ID.
    func submitTestFeatureRequest(
        userId: String,
        description: String,
        appVersion: String,
        completion: @escaping (Error?) -> Void
    ) {
        let data: [String: Any] = [
            "description": description,
            "appVersion": appVersion,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "new"
        ]

        db.collection("users")
            .document(userId)
            .collection("feature-requests")
            .addDocument(data: data) { error in
                completion(error)
            }
    }
}
