// EngineTelemetryService.swift
// Thump iOS
//
// Uploads engine pipeline traces to Firebase Firestore for quality
// baselining. Uses a SHA256-hashed Apple Sign-In user ID for
// pseudonymous tracking. Gated behind a user consent toggle
// (always enabled in DEBUG builds).
// Platforms: iOS 17+

import Foundation
import CryptoKit
import FirebaseFirestore

// MARK: - Engine Telemetry Service

/// Uploads ``PipelineTrace`` documents to Firestore for engine quality
/// baselining and debugging.
///
/// Each trace captures computed scores, confidence levels, and timing
/// from all 9 engines — never raw HealthKit values. Documents are stored
/// under `users/{hashedUserId}/traces/{autoId}`.
///
/// Usage:
/// ```swift
/// // At startup:
/// EngineTelemetryService.shared.configureUserId()
///
/// // After each dashboard refresh:
/// EngineTelemetryService.shared.uploadTrace(trace)
/// ```
final class EngineTelemetryService {

    // MARK: - Singleton

    static let shared = EngineTelemetryService()

    // MARK: - Properties

    /// The SHA256-hashed Apple user identifier for pseudonymous tracking.
    private(set) var hashedUserId: String?

    /// Firestore database reference.
    private let db = Firestore.firestore()

    // MARK: - Initialization

    private init() {}

    // MARK: - User ID Configuration

    /// Loads the Apple Sign-In user identifier from the Keychain and
    /// creates a SHA256 hash for pseudonymous Firestore document paths.
    ///
    /// Call this after verifying the Apple Sign-In credential in
    /// `performStartupTasks()`.
    func configureUserId() {
        guard let appleId = AppleSignInService.loadUserIdentifier() else {
            AppLogger.engine.warning("[EngineTelemetry] No Apple user ID found — telemetry disabled.")
            return
        }

        let hash = SHA256.hash(data: Data(appleId.utf8))
        hashedUserId = hash.compactMap { String(format: "%02x", $0) }.joined()
        AppLogger.engine.info("[EngineTelemetry] User ID configured (hashed).")
    }

    // MARK: - Consent Check

    /// Whether telemetry uploads are enabled.
    ///
    /// Reads the user's opt-in preference from `thump_telemetry_consent`.
    /// Apple Guideline 5.1.1(ii) requires consent for all data collection,
    /// including DEBUG and TestFlight builds.
    var isUploadEnabled: Bool {
        UserDefaults.standard.bool(forKey: "thump_telemetry_consent")
    }

    // MARK: - Upload

    /// Uploads a complete pipeline trace document to Firestore.
    ///
    /// Fire-and-forget: the write is queued by the Firestore SDK
    /// (including offline persistence) and errors are logged but
    /// never surfaced to the user.
    ///
    /// - Parameter trace: The pipeline trace to upload.
    func uploadTrace(_ trace: PipelineTrace) {
        guard isUploadEnabled else { return }

        guard let userId = hashedUserId else {
            AppLogger.engine.debug("[EngineTelemetry] No user ID — skipping trace upload.")
            return
        }

        let docData = trace.toFirestoreData()

        db.collection("users")
            .document(userId)
            .collection("traces")
            .addDocument(data: docData) { error in
                if let error {
                    AppLogger.engine.warning("[EngineTelemetry] Upload failed: \(error.localizedDescription)")
                } else {
                    AppLogger.engine.debug("[EngineTelemetry] Trace uploaded successfully.")
                }
            }
    }
}
