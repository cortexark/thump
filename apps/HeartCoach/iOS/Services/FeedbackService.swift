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

    /// Uploads a bug report document to Firestore including all current health
    /// metrics and engine outputs so the team can reproduce the exact UI state.
    func submitBugReport(
        description: String,
        appVersion: String,
        deviceModel: String,
        iosVersion: String,
        healthMetrics: [String: Any],
        completion: ((Error?) -> Void)? = nil
    ) {
        let userId = EngineTelemetryService.shared.hashedUserId ?? "anonymous"

        var data: [String: Any] = [
            "description": description,
            "appVersion": appVersion,
            "deviceModel": deviceModel,
            "iosVersion": iosVersion,
            "timestamp": FieldValue.serverTimestamp(),
            "status": "new",
            "healthMetrics": healthMetrics
        ]

        // Add user profile context (age, sex) for metric interpretation
        let profile = LocalStore().profile
        if let dob = profile.dateOfBirth {
            let ageYears = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
            data["userAge"] = ageYears
        }
        data["userSex"] = profile.biologicalSex.rawValue

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
