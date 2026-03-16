// BugReportFirestoreTests.swift
// Thump Tests
//
// End-to-end integration tests for bug report upload to Firestore.
// Submits a mock bug report, reads it back, and validates all fields.
// Platforms: iOS 17+

import XCTest
import FirebaseCore
import FirebaseFirestore
@testable import Thump

// MARK: - Bug Report Firestore Integration Tests

final class BugReportFirestoreTests: XCTestCase {

    private var db: Firestore!
    private let testUserId = "test-bug-report-user"

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        db = Firestore.firestore()
    }

    // MARK: - Tests

    /// Submits a bug report to Firestore and reads it back to validate all fields.
    func testBugReportUploadsAndReadsBackFromFirestore() async throws {
        let description = "Test bug: buttons not responding on dashboard"
        let appVersion = "1.0.0 (42)"
        let deviceModel = "iPhone"
        let iosVersion = "18.3"

        // Step 1: Upload the bug report
        let uploadExpectation = expectation(description: "Bug report uploaded")

        BugReportService.shared.submitTestReport(
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

        // Step 2: Wait for Firestore to process
        try await Task.sleep(nanoseconds: 3_000_000_000)

        // Step 3: Read back from Firestore
        let collection = db.collection("users")
            .document(testUserId)
            .collection("bug-reports")

        let snapshot = try await collection
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments()

        XCTAssertFalse(snapshot.documents.isEmpty, "Should have at least one bug report document")

        let doc = try XCTUnwrap(snapshot.documents.first)
        let data = doc.data()

        // Step 4: Validate all fields
        XCTAssertEqual(data["description"] as? String, description)
        XCTAssertEqual(data["appVersion"] as? String, appVersion)
        XCTAssertEqual(data["deviceModel"] as? String, deviceModel)
        XCTAssertEqual(data["iosVersion"] as? String, iosVersion)
        XCTAssertEqual(data["status"] as? String, "new")
        XCTAssertNotNil(data["timestamp"], "Should have a server timestamp")

        print("[BugReportTest] Document ID: \(doc.documentID)")
        print("[BugReportTest] All fields validated successfully")
    }

    /// Tests that multiple bug reports from the same user are stored correctly.
    func testMultipleBugReportsStoredCorrectly() async throws {
        let reports = [
            "First bug: crash on launch",
            "Second bug: settings not saving",
            "Third bug: notifications not appearing"
        ]

        // Upload 3 reports
        for report in reports {
            let expectation = expectation(description: "Report uploaded: \(report)")
            BugReportService.shared.submitTestReport(
                userId: testUserId,
                description: report,
                appVersion: "1.0.0 (1)",
                deviceModel: "iPhone",
                iosVersion: "18.3"
            ) { error in
                XCTAssertNil(error)
                expectation.fulfill()
            }
            await fulfillment(of: [expectation], timeout: 15)
        }

        // Wait for processing
        try await Task.sleep(nanoseconds: 3_000_000_000)

        // Read back all reports
        let snapshot = try await db.collection("users")
            .document(testUserId)
            .collection("bug-reports")
            .order(by: "timestamp", descending: true)
            .limit(to: 3)
            .getDocuments()

        XCTAssertGreaterThanOrEqual(snapshot.documents.count, 3,
            "Should have at least 3 bug report documents")

        print("[BugReportTest] Found \(snapshot.documents.count) reports for test user")
    }
}
