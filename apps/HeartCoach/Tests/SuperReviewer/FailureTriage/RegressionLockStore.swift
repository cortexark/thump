// RegressionLockStore.swift
// Thump Tests — Super Reviewer Failure Triage
//
// Manages regression locks: frozen (persona, journey, day, timestamp + ruleID)
// combinations that must pass on every CI run.
// Locks live in Tests/SuperReviewer/RegressionLocks/*.json — committed to git.

import Foundation

// MARK: - Regression Lock Store

enum RegressionLockStore {

    // MARK: - Lock Directory

    private static var lockDirectoryURL: URL {
        // Navigate from FailureTriage/ → SuperReviewer/ → RegressionLocks/
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // FailureTriage/
            .deletingLastPathComponent()   // SuperReviewer/
            .appendingPathComponent("RegressionLocks")
    }

    // MARK: - Load Locks

    /// Load all regression locks from disk.
    static func loadAll() -> [LockedRegressionCapture] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: lockDirectoryURL,
            includingPropertiesForKeys: nil
        ) else { return [] }

        let decoder = JSONDecoder()
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(LockedRegressionCapture.self, from: data)
            }
    }

    // MARK: - Save Lock

    /// Save a new regression lock to disk.
    static func save(_ lock: LockedRegressionCapture) {
        let fm = FileManager.default
        try? fm.createDirectory(at: lockDirectoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let filename = sanitizeFilename(lock.lockID) + ".json"
        let url = lockDirectoryURL.appendingPathComponent(filename)

        if let data = try? encoder.encode(lock) {
            try? data.write(to: url)
            print("[RegressionLock] Saved lock: \(filename)")
        }
    }

    // MARK: - Create and Save Lock

    /// Create a regression lock for a fixed bug and save it to disk.
    /// Call this after confirming a fix works.
    @discardableResult
    static func createAndSaveLock(
        captureID: String,
        criterionID: String,
        ruleID: String,
        personaName: String,
        journeyID: String,
        dayIndex: Int,
        timeStampLabel: String,
        fixDescription: String,
        gitSHA: String? = nil
    ) -> LockedRegressionCapture {
        let lockID = "lock_\(criterionID.replacingOccurrences(of: "-", with: ""))_\(sanitizeForID(personaName))_\(sanitizeForID(journeyID))_d\(dayIndex)"

        let lock = LockedRegressionCapture(
            lockID: lockID,
            captureID: captureID,
            criterionID: criterionID,
            ruleID: ruleID,
            expectedVerdict: "PASS",
            fixDescription: fixDescription,
            lockedAt: ISO8601DateFormatter().string(from: Date()),
            lockedByCommit: gitSHA,
            personaName: personaName,
            journeyID: journeyID,
            dayIndex: dayIndex,
            timeStampLabel: timeStampLabel
        )

        save(lock)
        return lock
    }

    // MARK: - Check Regression Locks

    /// Verify all regression locks against a batch verification result.
    /// Returns violations (locks that are now failing = regressions introduced).
    static func checkRegressionLocks(
        captures: [SuperReviewerCapture],
        batchResult: BatchVerificationResult
    ) -> [RegressionLockViolation] {
        let locks = loadAll()
        guard !locks.isEmpty else { return [] }

        // Build captureID → VerificationResult lookup
        var resultIndex: [String: VerificationResult] = [:]
        for result in batchResult.results {
            resultIndex[result.captureID] = result
        }

        var violations: [RegressionLockViolation] = []

        for lock in locks {
            guard let result = resultIndex[lock.captureID] else {
                // Capture not in batch — lock target may have been renamed
                print("[RegressionLock] WARNING: Lock '\(lock.lockID)' target '\(lock.captureID)' not found in batch.")
                continue
            }

            // Check if the locked ruleID still fires
            let ruleFired = result.violations.contains { $0.ruleID == lock.ruleID }
            if ruleFired {
                let matchingViolations = result.violations.filter { $0.ruleID == lock.ruleID }
                let summary = matchingViolations.map { "\($0.field): \($0.message)" }.joined(separator: "; ")
                violations.append(RegressionLockViolation(
                    lock: lock,
                    message: "Regression! Lock '\(lock.lockID)' expected PASS for \(lock.ruleID) on '\(lock.captureID)' but got: \(summary)"
                ))
            }
        }

        return violations
    }

    // MARK: - Helpers

    private static func sanitizeFilename(_ string: String) -> String {
        string
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "/", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }

    private static func sanitizeForID(_ string: String) -> String {
        string
            .components(separatedBy: " ").first ?? string
    }
}
