// FirestoreTelemetryIntegrationTests.swift
// ThumpTests
//
// End-to-end integration test that feeds mock health metrics through
// the full 9-engine pipeline, uploads a PipelineTrace to Firestore,
// then reads it back to validate the data landed correctly.
//
// Requires: GoogleService-Info.plist in the app bundle and a Firestore
// database in test mode.
// Platforms: iOS 17+

import XCTest
import FirebaseCore
import FirebaseFirestore
@testable import Thump

// MARK: - Firestore Telemetry Integration Tests

/// Runs the full engine pipeline with mock health data, uploads a
/// PipelineTrace to Firestore, then reads it back and validates
/// every engine's data is present and correct.
@MainActor
final class FirestoreTelemetryIntegrationTests: XCTestCase {

    /// Fixed test user ID so traces are easy to find in the console.
    private let testUserId = "test-telemetry-user"

    private var defaults: UserDefaults?
    private var localStore: LocalStore?
    private var db: Firestore!

    override func setUp() {
        super.setUp()
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        db = Firestore.firestore()
        defaults = UserDefaults(suiteName: "com.thump.telemetry-test.\(UUID().uuidString)")
        localStore = defaults.map { LocalStore(defaults: $0) }
    }

    override func tearDown() {
        defaults = nil
        localStore = nil
        db = nil
        super.tearDown()
    }

    // MARK: - Full Pipeline → Upload → Read Back → Validate

    /// Runs mock health data through all 9 engines, uploads the trace
    /// to Firestore, reads it back, and validates every field.
    func testFullPipelineUploadsAndReadsBackFromFirestore() async throws {
        let localStore = try XCTUnwrap(localStore)

        // Set date of birth so BioAge engine runs
        localStore.profile.dateOfBirth = Calendar.current.date(
            byAdding: .year, value: -35, to: Date()
        )
        localStore.saveProfile()

        // 21 days of mock history + today
        let history = MockData.mockHistory(days: 21)
        let today = MockData.mockTodaySnapshot

        let provider = MockHealthDataProvider(
            todaySnapshot: today,
            history: history,
            shouldAuthorize: true
        )

        let viewModel = DashboardViewModel(
            healthKitService: provider,
            localStore: localStore
        )

        // Run the full pipeline
        await viewModel.refresh()

        // Verify all engines produced output locally
        let assessment = try XCTUnwrap(viewModel.assessment, "HeartTrendEngine failed")
        let stress = try XCTUnwrap(viewModel.stressResult, "StressEngine failed")
        let readiness = try XCTUnwrap(viewModel.readinessResult, "ReadinessEngine failed")
        let coaching = try XCTUnwrap(viewModel.coachingReport, "CoachingEngine failed")
        let zones = try XCTUnwrap(viewModel.zoneAnalysis, "ZoneAnalysis failed")
        let buddies = try XCTUnwrap(viewModel.buddyRecommendations, "BuddyEngine failed")
        XCTAssertNil(viewModel.errorMessage, "Pipeline error: \(viewModel.errorMessage ?? "")")

        // Build trace
        var trace = PipelineTrace(
            timestamp: Date(),
            pipelineDurationMs: 42.0,
            historyDays: history.count
        )
        trace.heartTrend = HeartTrendTrace(from: assessment, durationMs: 10)
        trace.stress = StressTrace(from: stress, durationMs: 5)
        trace.readiness = ReadinessTrace(from: readiness, durationMs: 3)
        if let bioAge = viewModel.bioAgeResult {
            trace.bioAge = BioAgeTrace(from: bioAge, durationMs: 2)
        }
        trace.coaching = CoachingTrace(from: coaching, durationMs: 4)
        trace.zoneAnalysis = ZoneAnalysisTrace(from: zones, durationMs: 1)
        trace.buddy = BuddyTrace(from: buddies, durationMs: 6)

        // Upload to Firestore
        let docData = trace.toFirestoreData()
        let collectionRef = db.collection("users")
            .document(testUserId)
            .collection("traces")

        let uploadExp = expectation(description: "Firestore upload")
        var uploadedDocId: String?

        collectionRef.addDocument(data: docData) { error in
            XCTAssertNil(error, "Upload failed: \(error?.localizedDescription ?? "")")
            uploadExp.fulfill()
        }

        await fulfillment(of: [uploadExp], timeout: 15.0)

        // Read back the most recent trace
        let readExp = expectation(description: "Firestore read-back")
        var readDoc: [String: Any]?

        collectionRef
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                XCTAssertNil(error, "Read failed: \(error?.localizedDescription ?? "")")
                readDoc = snapshot?.documents.first?.data()
                uploadedDocId = snapshot?.documents.first?.documentID
                readExp.fulfill()
            }

        await fulfillment(of: [readExp], timeout: 15.0)

        let doc = try XCTUnwrap(readDoc, "No document found in Firestore")

        // MARK: Validate top-level fields
        XCTAssertEqual(doc["pipelineDurationMs"] as? Double, 42.0)
        XCTAssertEqual(doc["historyDays"] as? Int, history.count)
        XCTAssertNotNil(doc["appVersion"] as? String)
        XCTAssertNotNil(doc["buildNumber"] as? String)
        XCTAssertNotNil(doc["deviceModel"] as? String)

        // MARK: Validate HeartTrend
        let ht = try XCTUnwrap(doc["heartTrend"] as? [String: Any], "heartTrend missing")
        XCTAssertEqual(ht["status"] as? String, assessment.status.rawValue)
        XCTAssertEqual(ht["confidence"] as? String, assessment.confidence.rawValue)
        XCTAssertNotNil(ht["anomalyScore"] as? Double)
        XCTAssertNotNil(ht["regressionFlag"] as? Bool)
        XCTAssertNotNil(ht["stressFlag"] as? Bool)
        XCTAssertEqual(ht["durationMs"] as? Double, 10)
        print("  ✅ heartTrend: status=\(ht["status"] ?? ""), confidence=\(ht["confidence"] ?? "")")

        // MARK: Validate Stress
        let st = try XCTUnwrap(doc["stress"] as? [String: Any], "stress missing")
        XCTAssertEqual(st["score"] as? Double, stress.score)
        XCTAssertEqual(st["level"] as? String, stress.level.rawValue)
        XCTAssertEqual(st["mode"] as? String, stress.mode.rawValue)
        XCTAssertEqual(st["confidence"] as? String, stress.confidence.rawValue)
        print("  ✅ stress: score=\(st["score"] ?? ""), level=\(st["level"] ?? "")")

        // MARK: Validate Readiness
        let rd = try XCTUnwrap(doc["readiness"] as? [String: Any], "readiness missing")
        XCTAssertEqual(rd["score"] as? Int, readiness.score)
        XCTAssertEqual(rd["level"] as? String, readiness.level.rawValue)
        XCTAssertNotNil(rd["pillarScores"] as? [String: Any])
        print("  ✅ readiness: score=\(rd["score"] ?? ""), level=\(rd["level"] ?? "")")

        // MARK: Validate BioAge (optional — depends on date of birth)
        if let bioAge = viewModel.bioAgeResult {
            let ba = try XCTUnwrap(doc["bioAge"] as? [String: Any], "bioAge missing")
            XCTAssertEqual(ba["bioAge"] as? Int, bioAge.bioAge)
            XCTAssertEqual(ba["chronologicalAge"] as? Int, bioAge.chronologicalAge)
            XCTAssertEqual(ba["difference"] as? Int, bioAge.difference)
            XCTAssertEqual(ba["category"] as? String, bioAge.category.rawValue)
            print("  ✅ bioAge: \(ba["bioAge"] ?? "")y (chrono=\(ba["chronologicalAge"] ?? ""))")
        }

        // MARK: Validate Coaching
        let co = try XCTUnwrap(doc["coaching"] as? [String: Any], "coaching missing")
        XCTAssertEqual(co["weeklyProgressScore"] as? Int, coaching.weeklyProgressScore)
        XCTAssertNotNil(co["insightCount"] as? Int)
        XCTAssertNotNil(co["streakDays"] as? Int)
        print("  ✅ coaching: progress=\(co["weeklyProgressScore"] ?? ""), insights=\(co["insightCount"] ?? "")")

        // MARK: Validate ZoneAnalysis
        let za = try XCTUnwrap(doc["zoneAnalysis"] as? [String: Any], "zoneAnalysis missing")
        XCTAssertEqual(za["overallScore"] as? Int, zones.overallScore)
        XCTAssertNotNil(za["pillarCount"] as? Int)
        XCTAssertNotNil(za["hasRecommendation"] as? Bool)
        print("  ✅ zoneAnalysis: score=\(za["overallScore"] ?? ""), pillars=\(za["pillarCount"] ?? "")")

        // MARK: Validate Buddy
        let bu = try XCTUnwrap(doc["buddy"] as? [String: Any], "buddy missing")
        XCTAssertEqual(bu["count"] as? Int, buddies.count)
        XCTAssertNotNil(bu["durationMs"] as? Double)
        print("  ✅ buddy: count=\(bu["count"] ?? ""), topPriority=\(bu["topPriority"] ?? "none")")

        print("\n✅ Full pipeline trace validated in Firestore!")
        print("   Document: users/\(testUserId)/traces/\(uploadedDocId ?? "?")")
    }

    // MARK: - All Personas → Upload → Read Back

    /// Runs every synthetic persona through the pipeline, uploads
    /// traces, then reads them all back and validates each one.
    func testAllPersonasUploadAndReadBackFromFirestore() async throws {
        let personas: [MockData.Persona] = [
            .athleticMale, .athleticFemale,
            .normalMale, .normalFemale,
            .couchPotatoMale, .couchPotatoFemale,
            .overweightMale, .overweightFemale,
            .underwieghtFemale,
            .seniorActive
        ]

        let collectionRef = db.collection("users")
            .document(testUserId)
            .collection("persona-traces")

        var uploadedCount = 0

        for persona in personas {
            let personaDefaults = UserDefaults(
                suiteName: "com.thump.persona-test.\(UUID().uuidString)"
            )!
            let store = LocalStore(defaults: personaDefaults)
            store.profile.dateOfBirth = Calendar.current.date(
                byAdding: .year, value: -35, to: Date()
            )
            store.saveProfile()

            let history = MockData.personaHistory(persona, days: 21)
            guard let today = history.last else { continue }

            let provider = MockHealthDataProvider(
                todaySnapshot: today,
                history: Array(history.dropLast()),
                shouldAuthorize: true
            )

            let viewModel = DashboardViewModel(
                healthKitService: provider,
                localStore: store
            )

            await viewModel.refresh()

            let assessment = try XCTUnwrap(viewModel.assessment, "\(persona) assessment nil")

            // Build trace
            var trace = PipelineTrace(
                timestamp: Date(),
                pipelineDurationMs: 0,
                historyDays: history.count
            )
            trace.heartTrend = HeartTrendTrace(from: assessment, durationMs: 0)
            if let s = viewModel.stressResult {
                trace.stress = StressTrace(from: s, durationMs: 0)
            }
            if let r = viewModel.readinessResult {
                trace.readiness = ReadinessTrace(from: r, durationMs: 0)
            }
            if let b = viewModel.bioAgeResult {
                trace.bioAge = BioAgeTrace(from: b, durationMs: 0)
            }
            if let c = viewModel.coachingReport {
                trace.coaching = CoachingTrace(from: c, durationMs: 0)
            }
            if let z = viewModel.zoneAnalysis {
                trace.zoneAnalysis = ZoneAnalysisTrace(from: z, durationMs: 0)
            }
            if let recs = viewModel.buddyRecommendations {
                trace.buddy = BuddyTrace(from: recs, durationMs: 0)
            }

            // Upload with persona name
            let personaName = String(describing: persona)
            let docData = trace.toFirestoreData().merging(
                ["persona": personaName],
                uniquingKeysWith: { _, new in new }
            )

            let uploadExp = expectation(description: "Upload \(personaName)")
            collectionRef.addDocument(data: docData) { error in
                XCTAssertNil(error, "\(personaName) upload failed: \(error?.localizedDescription ?? "")")
                uploadExp.fulfill()
            }
            await fulfillment(of: [uploadExp], timeout: 15.0)
            uploadedCount += 1
            print("  ✅ \(personaName) uploaded")
        }

        // Read back ALL persona traces and validate
        let readExp = expectation(description: "Read all persona traces")
        var readDocs: [QueryDocumentSnapshot] = []

        collectionRef
            .order(by: "timestamp", descending: true)
            .limit(to: uploadedCount)
            .getDocuments { snapshot, error in
                XCTAssertNil(error, "Read-back failed: \(error?.localizedDescription ?? "")")
                readDocs = snapshot?.documents ?? []
                readExp.fulfill()
            }

        await fulfillment(of: [readExp], timeout: 15.0)

        XCTAssertGreaterThanOrEqual(readDocs.count, uploadedCount,
            "Expected \(uploadedCount) persona traces, found \(readDocs.count)")

        // Validate each read-back document has required engine fields
        for doc in readDocs {
            let data = doc.data()
            let persona = data["persona"] as? String ?? "unknown"

            // Every trace must have heartTrend (primary engine)
            let ht = try XCTUnwrap(data["heartTrend"] as? [String: Any],
                "\(persona): heartTrend missing")
            XCTAssertNotNil(ht["status"], "\(persona): heartTrend.status missing")
            XCTAssertNotNil(ht["confidence"], "\(persona): heartTrend.confidence missing")
            XCTAssertNotNil(ht["anomalyScore"], "\(persona): heartTrend.anomalyScore missing")

            // Stress (optional — some personas may not produce stress)
            let stressScore: Any
            if let st = data["stress"] as? [String: Any] {
                XCTAssertNotNil(st["score"], "\(persona): stress.score missing")
                XCTAssertNotNil(st["level"], "\(persona): stress.level missing")
                stressScore = st["score"] ?? "nil"
            } else {
                stressScore = "n/a"
            }

            // Readiness (optional — some personas may not produce readiness)
            let readinessScore: Any
            if let rd = data["readiness"] as? [String: Any] {
                XCTAssertNotNil(rd["score"], "\(persona): readiness.score missing")
                readinessScore = rd["score"] ?? "nil"
            } else {
                readinessScore = "n/a"
            }

            // Metadata
            XCTAssertNotNil(data["appVersion"], "\(persona): appVersion missing")
            XCTAssertNotNil(data["deviceModel"], "\(persona): deviceModel missing")

            print("  ✅ \(persona) read-back validated: " +
                "status=\(ht["status"] ?? ""), " +
                "stress=\(stressScore), " +
                "readiness=\(readinessScore)")
        }

        print("\n📊 All \(readDocs.count) persona traces validated in Firestore!")
        print("   Collection: users/\(testUserId)/persona-traces/")
    }
}
