// BugReportService.swift
// Thump iOS
//
// Uploads bug reports to Firebase Firestore for easy querying and tracking.
// Reports are stored under users/{hashedUserId}/bug-reports/{autoId}.
// Platforms: iOS 17+

import Foundation
import FirebaseFirestore

// MARK: - Bug Report Service

/// Uploads bug reports to Firestore so the developer can query and triage
/// issues from the Firebase Console without relying on email.
final class BugReportService {

    // MARK: - Singleton

    static let shared = BugReportService()

    // MARK: - Properties

    private let db = Firestore.firestore()

    // MARK: - Initialization

    private init() {}

    // MARK: - Submit Report

    /// Uploads a bug report document to Firestore.
    ///
    /// - Parameters:
    ///   - description: The user's bug description text.
    ///   - appVersion: App version string (e.g., "1.0.0 (1)").
    ///   - deviceModel: Device model (e.g., "iPhone").
    ///   - iosVersion: iOS version (e.g., "18.3").
    func submitReport(
        description: String,
        appVersion: String,
        deviceModel: String,
        iosVersion: String
    ) {
        let userId = EngineTelemetryService.shared.hashedUserId ?? "anonymous"

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
                if let error {
                    AppLogger.engine.warning("[BugReport] Upload failed: \(error.localizedDescription)")
                } else {
                    AppLogger.engine.info("[BugReport] Report uploaded successfully")
                }
            }
    }

    /// Uploads a bug report for testing purposes with a specific user ID.
    /// Used by integration tests to verify Firestore upload and read-back.
    func submitTestReport(
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
}
