// AccountDeletionService.swift
// Thump iOS
//
// Handles full account deletion: clears Firestore user data,
// removes Keychain credentials, and resets local state.
// Required by Apple Guideline 5.1.1(v) for apps that support
// account creation via Sign in with Apple.
// Platforms: iOS 17+

import Foundation
import FirebaseFirestore

// MARK: - Account Deletion Service

/// Deletes all user data from Firestore and resets local state.
///
/// Apple requires apps that support account creation to also
/// offer account deletion within the app. This service handles
/// the server-side cleanup (Firestore subcollections) and the
/// client-side cleanup (Keychain + UserDefaults).
enum AccountDeletionService {

    // MARK: - Firestore Subcollections

    /// All Firestore subcollections stored under `users/{hashedUserId}/`.
    private static let subcollections = [
        "traces",
        "events",
        "bug-reports",
        "feature-requests"
    ]

    // MARK: - Delete Account

    /// Deletes all Firestore data for the current user, clears local
    /// credentials, and resets the local profile.
    ///
    /// - Parameters:
    ///   - localStore: The local store to reset.
    ///   - completion: Called when deletion completes. The error is nil on success.
    static func deleteAccount(
        localStore: LocalStore,
        completion: @escaping (Error?) -> Void
    ) {
        guard let userId = EngineTelemetryService.shared.hashedUserId else {
            // No server data exists — just clean up locally
            performLocalCleanup(localStore: localStore)
            completion(nil)
            return
        }

        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(userId)
        let group = DispatchGroup()
        var firstError: Error?

        // Delete each subcollection's documents
        for subcollection in subcollections {
            group.enter()
            deleteSubcollection(
                parentDoc: userDoc,
                name: subcollection
            ) { error in
                if let error, firstError == nil {
                    firstError = error
                }
                group.leave()
            }
        }

        // Delete the user document itself
        group.enter()
        userDoc.delete { error in
            if let error, firstError == nil {
                firstError = error
            }
            group.leave()
        }

        group.notify(queue: .main) {
            // Clean up local state regardless of server errors
            performLocalCleanup(localStore: localStore)
            completion(firstError)
        }
    }

    // MARK: - Private Helpers

    /// Deletes all documents in a Firestore subcollection in batches.
    private static func deleteSubcollection(
        parentDoc: DocumentReference,
        name: String,
        completion: @escaping (Error?) -> Void
    ) {
        let collectionRef = parentDoc.collection(name)
        collectionRef.limit(to: 100).getDocuments { snapshot, error in
            if let error {
                completion(error)
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                completion(nil)
                return
            }

            let batch = collectionRef.firestore.batch()
            for doc in documents {
                batch.deleteDocument(doc.reference)
            }

            batch.commit { batchError in
                if let batchError {
                    completion(batchError)
                    return
                }

                // Recurse if there might be more documents
                if documents.count == 100 {
                    deleteSubcollection(
                        parentDoc: parentDoc,
                        name: name,
                        completion: completion
                    )
                } else {
                    completion(nil)
                }
            }
        }
    }

    /// Clears all local credentials and resets UserDefaults state.
    private static func performLocalCleanup(localStore: LocalStore) {
        // Remove Apple Sign-In credential from Keychain
        AppleSignInService.deleteUserIdentifier()

        // Reset local profile
        localStore.profile = UserProfile()
        localStore.saveProfile()

        // Clear persisted flags
        UserDefaults.standard.removeObject(forKey: "thump_signed_in")
        UserDefaults.standard.removeObject(forKey: "thump_legal_accepted_v1")
        UserDefaults.standard.removeObject(forKey: "thump_launch_congrats_shown")
        UserDefaults.standard.removeObject(forKey: "thump_telemetry_consent")
        UserDefaults.standard.removeObject(forKey: "thump_anomaly_alerts_enabled")
        UserDefaults.standard.removeObject(forKey: "thump_nudge_reminders_enabled")
        UserDefaults.standard.removeObject(forKey: "thump_design_variant_b")
    }
}
