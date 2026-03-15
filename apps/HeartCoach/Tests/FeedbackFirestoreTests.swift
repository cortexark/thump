// FeedbackFirestoreTests.swift
// Thump Tests
//
// End-to-end integration tests for bug report and feature request
// upload to Firestore. Submits mock data, reads it back, and
// validates all fields.
// Platforms: iOS 17+

import XCTest
import FirebaseCore
import FirebaseFirestore
@testable import Thump

// MARK: - Feedback Firestore Integration Tests

final class FeedbackFirestoreTests: XCTestCase {

    private var db: Firestore!
    private let testUserId = "test-feedback-user"

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        db = Firestore.firestore()
    }

    // MARK: - Bug Report Tests

    /// Submits a bug report to Firestore and reads it back to validate all fields.
    func testBugReportUploadsAndReadsBackFromFirestore() async throws {
        let description = "Test bug: buttons not responding on dashboard"
        let appVersion = "1.0.0 (42)"
        let deviceModel = "iPhone"
        let iosVersion = "18.3"

        // Upload
        let uploadExpectation = expectation(description: "Bug report uploaded")
        FeedbackService.shared.submitTestBugReport(
            userId: testUserId,
            description: description,
            appVersion: appVersion,
            deviceModel: deviceModel,
            iosVersion: iosVersion
        ) { error in
            XCTAssertNil(error, "Bug report upload should succeed: \(error?.localizedDescription ?? "")")
            uploadExpectation.fulfill()
        }
        await fulfillment(of: [uploadExpectation], timeout: 15)

        // Wait for Firestore processing
        try await Task.sleep(nanoseconds: 3_000_000_000)

        // Read back
        let snapshot = try await db.collection("users")
            .document(testUserId)
            .collection("bug-reports")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments()

        XCTAssertFalse(snapshot.documents.isEmpty, "Should have at least one bug report document")

        let doc = try XCTUnwrap(snapshot.documents.first)
        let data = doc.data()

        XCTAssertEqual(data["description"] as? String, description)
        XCTAssertEqual(data["appVersion"] as? String, appVersion)
        XCTAssertEqual(data["deviceModel"] as? String, deviceModel)
        XCTAssertEqual(data["iosVersion"] as? String, iosVersion)
        XCTAssertEqual(data["status"] as? String, "new")
        XCTAssertNotNil(data["timestamp"], "Should have a server timestamp")

        print("[FeedbackTest] Bug report validated: \(doc.documentID)")
    }

    // MARK: - Feature Request Tests

    /// Submits a feature request to Firestore and reads it back to validate all fields.
    func testFeatureRequestUploadsAndReadsBackFromFirestore() async throws {
        let description = "Feature request: add dark mode support"
        let appVersion = "1.0.0 (42)"

        // Upload
        let uploadExpectation = expectation(description: "Feature request uploaded")
        FeedbackService.shared.submitTestFeatureRequest(
            userId: testUserId,
            description: description,
            appVersion: appVersion
        ) { error in
            XCTAssertNil(error, "Feature request upload should succeed: \(error?.localizedDescription ?? "")")
            uploadExpectation.fulfill()
        }
        await fulfillment(of: [uploadExpectation], timeout: 15)

        // Wait for Firestore processing
        try await Task.sleep(nanoseconds: 3_000_000_000)

        // Read back
        let snapshot = try await db.collection("users")
            .document(testUserId)
            .collection("feature-requests")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments()

        XCTAssertFalse(snapshot.documents.isEmpty, "Should have at least one feature request document")

        let doc = try XCTUnwrap(snapshot.documents.first)
        let data = doc.data()

        XCTAssertEqual(data["description"] as? String, description)
        XCTAssertEqual(data["appVersion"] as? String, appVersion)
        XCTAssertEqual(data["status"] as? String, "new")
        XCTAssertNotNil(data["timestamp"], "Should have a server timestamp")

        print("[FeedbackTest] Feature request validated: \(doc.documentID)")
    }

    /// Tests that multiple feature requests from the same user are stored correctly.
    func testMultipleFeatureRequestsStoredCorrectly() async throws {
        let requests = [
            "Add widget support",
            "Dark mode please",
            "Export to PDF"
        ]

        for request in requests {
            let exp = expectation(description: "Request uploaded: \(request)")
            FeedbackService.shared.submitTestFeatureRequest(
                userId: testUserId,
                description: request,
                appVersion: "1.0.0 (1)"
            ) { error in
                XCTAssertNil(error)
                exp.fulfill()
            }
            await fulfillment(of: [exp], timeout: 15)
        }

        try await Task.sleep(nanoseconds: 3_000_000_000)

        let snapshot = try await db.collection("users")
            .document(testUserId)
            .collection("feature-requests")
            .order(by: "timestamp", descending: true)
            .limit(to: 3)
            .getDocuments()

        XCTAssertGreaterThanOrEqual(snapshot.documents.count, 3,
            "Should have at least 3 feature request documents")

        print("[FeedbackTest] Found \(snapshot.documents.count) feature requests for test user")
    }
}
