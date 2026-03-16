// FeedbackService.swift
// Thump iOS
//
// Uploads bug reports and feature requests to Firebase Firestore.
// Reports are stored under users/{hashedUserId}/bug-reports/{autoId}
// and users/{hashedUserId}/feature-requests/{autoId}.
// Platforms: iOS 17+

import Foundation
import UIKit
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

    // MARK: - User Identification

    /// Returns a stable user ID for feedback documents.
    /// Prefers the hashed Apple Sign-In ID from EngineTelemetryService;
    /// falls back to a persistent UUID stored in UserDefaults so
    /// feedback is always attributable even without Apple Sign-In.
    private var feedbackUserId: String {
        if let hashedId = EngineTelemetryService.shared.hashedUserId {
            return hashedId
        }

        let key = "thump_feedback_device_id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }

        // Generate a stable ID from vendor ID + random UUID fallback
        let deviceId = UIDevice.current.identifierForVendor?.uuidString
            ?? UUID().uuidString
        let stableId = "device_\(deviceId)"
        UserDefaults.standard.set(stableId, forKey: key)
        return stableId
    }

    // MARK: - Bug Reports

    /// Uploads a bug report document to Firestore with optional diagnostic payload.
    func submitBugReport(
        description: String,
        appVersion: String,
        deviceModel: String,
        iosVersion: String,
        diagnosticPayload: [String: Any]? = nil
    ) {
        let userId = feedbackUserId

        var data: [String: Any] = [
            "description": description,
            "appVersion": appVersion,
            "deviceModel": deviceModel,
            "iosVersion": iosVersion,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "new"
        ]

        // Merge diagnostic payload if provided
        if let diagnostic = diagnosticPayload {
            for (key, value) in diagnostic where key != "description" {
                data[key] = value
            }
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
            }
    }

    /// Uploads a bug report for testing purposes with a specific user ID.
    func submitTestBugReport(
        userId: String,
        description: String,
        appVersion: String,
        deviceModel: String,
        iosVersion: String,
        completion: @escaping (Error?) -> Void
    ) {
        let data: [String: Any] = [
            "description": description,
            "appVersion": appVersion,
            "deviceModel": deviceModel,
            "iosVersion": iosVersion,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "new"
        ]

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
        let userId = feedbackUserId

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
