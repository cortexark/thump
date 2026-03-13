// StressViewActionTests.swift
// ThumpTests
//
// Tests for StressView action button behaviors: breathing session,
// walk suggestion, journal sheet, and watch connectivity messaging.

import XCTest
@testable import Thump

final class StressViewActionTests: XCTestCase {

    private var viewModel: StressViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        viewModel = StressViewModel()
    }

    @MainActor
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Breathing Session

    @MainActor
    func testBreathingSession_initiallyInactive() {
        XCTAssertFalse(viewModel.isBreathingSessionActive,
            "Breathing session should be inactive by default")
    }

    @MainActor
    func testStartBreathingSession_activatesSession() {
        viewModel.startBreathingSession()

        XCTAssertTrue(viewModel.isBreathingSessionActive,
            "Breathing session should be active after starting")
    }

    @MainActor
    func testStartBreathingSession_setsCountdown() {
        viewModel.startBreathingSession()

        XCTAssertGreaterThan(viewModel.breathingSecondsRemaining, 0,
            "Countdown should be positive after starting a breathing session")
    }

    @MainActor
    func testStopBreathingSession_deactivatesSession() {
        viewModel.startBreathingSession()
        viewModel.stopBreathingSession()

        XCTAssertFalse(viewModel.isBreathingSessionActive,
            "Breathing session should be inactive after stopping")
    }

    @MainActor
    func testStopBreathingSession_resetsCountdown() {
        viewModel.startBreathingSession()
        viewModel.stopBreathingSession()

        XCTAssertEqual(viewModel.breathingSecondsRemaining, 0,
            "Countdown should be zero after stopping")
    }

    // MARK: - Walk Suggestion

    @MainActor
    func testWalkSuggestion_initiallyHidden() {
        XCTAssertFalse(viewModel.walkSuggestionShown,
            "Walk suggestion should not be shown by default")
    }

    @MainActor
    func testShowWalkSuggestion_setsFlag() {
        viewModel.showWalkSuggestion()

        XCTAssertTrue(viewModel.walkSuggestionShown,
            "Walk suggestion should be shown after calling showWalkSuggestion")
    }

    // MARK: - Journal Sheet

    @MainActor
    func testJournalSheet_initiallyDismissed() {
        XCTAssertFalse(viewModel.isJournalSheetPresented,
            "Journal sheet should not be presented by default")
    }

    @MainActor
    func testPresentJournalSheet_setsFlag() {
        viewModel.presentJournalSheet()

        XCTAssertTrue(viewModel.isJournalSheetPresented,
            "Journal sheet should be presented after calling presentJournalSheet")
    }

    @MainActor
    func testPresentJournalSheet_setsPromptText() {
        let prompt = JournalPrompt(
            question: "What helped you relax today?",
            context: "Your stress was lower this afternoon",
            icon: "pencil.circle.fill",
            date: Date()
        )
        viewModel.presentJournalSheet(prompt: prompt)

        XCTAssertTrue(viewModel.isJournalSheetPresented)
        XCTAssertEqual(viewModel.activeJournalPrompt?.question,
            "What helped you relax today?")
    }

    // MARK: - Watch Connectivity (Open on Watch)

    @MainActor
    func testSendBreathToWatch_initiallyNotSent() {
        XCTAssertFalse(viewModel.didSendBreathPromptToWatch,
            "No breath prompt should be sent by default")
    }

    @MainActor
    func testSendBreathToWatch_setsFlag() {
        viewModel.sendBreathPromptToWatch()

        XCTAssertTrue(viewModel.didSendBreathPromptToWatch,
            "Flag should be set after sending breath prompt to watch")
    }

    // MARK: - handleSmartAction Routing

    @MainActor
    func testHandleSmartAction_journalPrompt_presentsSheet() {
        let prompt = JournalPrompt(
            question: "What's on your mind?",
            context: "Evening reflection",
            icon: "pencil.circle.fill",
            date: Date()
        )
        viewModel.smartActions = [.journalPrompt(prompt)]
        viewModel.handleSmartAction(viewModel.smartActions[0])

        XCTAssertTrue(viewModel.isJournalSheetPresented,
            "Journal sheet should be presented for journalPrompt action")
        XCTAssertEqual(viewModel.activeJournalPrompt?.question,
            "What's on your mind?")
    }

    @MainActor
    func testHandleSmartAction_breatheOnWatch_sendsToWatch() {
        let nudge = DailyNudge(
            category: .breathe,
            title: "Slow Breath",
            description: "Take a few slow breaths",
            durationMinutes: 3,
            icon: "wind"
        )
        viewModel.smartActions = [.breatheOnWatch(nudge)]
        viewModel.handleSmartAction(viewModel.smartActions[0])

        XCTAssertTrue(viewModel.didSendBreathPromptToWatch,
            "Breath prompt should be sent to watch for breatheOnWatch action")
    }

    @MainActor
    func testHandleSmartAction_activitySuggestion_showsWalkSuggestion() {
        let nudge = DailyNudge(
            category: .walk,
            title: "Take a Walk",
            description: "A short walk can help",
            durationMinutes: 10,
            icon: "figure.walk"
        )
        viewModel.smartActions = [.activitySuggestion(nudge)]
        viewModel.handleSmartAction(viewModel.smartActions[0])

        XCTAssertTrue(viewModel.walkSuggestionShown,
            "Walk suggestion should be shown for activitySuggestion action")
    }
}
