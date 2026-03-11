// DashboardView.swift
// Thump iOS
//
// The primary dashboard screen. Presents a daily greeting, the heart health
// status card, a two-column metric grid, a coaching nudge, and a streak badge.
// All features are free for all users. Data is loaded asynchronously from the
// view model and supports pull-to-refresh.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - DashboardView

/// Main dashboard displaying today's heart health assessment and metrics.
///
/// All metrics and coaching nudges are available to all users.
struct DashboardView: View {

    @EnvironmentObject private var connectivityService: ConnectivityService
    @EnvironmentObject private var healthKitService: HealthKitService
    @EnvironmentObject private var localStore: LocalStore

    // MARK: - View Model

    @StateObject private var viewModel = DashboardViewModel()
    @State private var hasBoundDependencies = false

    // MARK: - Grid Layout

    /// Two-column adaptive grid for metric tiles.
    private let metricColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Dashboard")
                .navigationBarTitleDisplayMode(.large)
                .task {
                    if !hasBoundDependencies {
                        viewModel.bind(
                            healthDataProvider: healthKitService,
                            localStore: localStore
                        )
                        hasBoundDependencies = true
                    }
                    await viewModel.refresh()
                }
                .onChange(of: viewModel.assessment) { _, newAssessment in
                    guard let newAssessment else { return }
                    connectivityService.sendAssessment(newAssessment)
                }
                .refreshable {
                    await viewModel.refresh()
                }
        }
    }

    // MARK: - Content Router

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.assessment == nil {
            loadingView
        } else if let error = viewModel.errorMessage {
            errorView(message: error)
        } else {
            dashboardScrollView
        }
    }

    // MARK: - Dashboard Content

    private var dashboardScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                greetingHeader
                statusSection
                metricsSection
                nudgeSection
                streakSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greetingText), \(formattedDate)")
    }

    /// Returns a time-of-day greeting with the user's name.
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        switch hour {
        case 0..<12:  greeting = "Good morning"
        case 12..<17: greeting = "Good afternoon"
        default:       greeting = "Good evening"
        }

        let name = viewModel.profileName
        if name.isEmpty {
            return greeting
        }
        return "\(greeting), \(name)"
    }

    /// Today's date formatted for the header.
    private var formattedDate: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    // MARK: - Status Section

    @ViewBuilder
    private var statusSection: some View {
        if let assessment = viewModel.assessment {
            StatusCardView(
                status: assessment.status,
                confidence: assessment.confidence,
                cardioScore: assessment.cardioScore,
                explanation: assessment.explanation
            )
        }
    }

    // MARK: - Metrics Grid

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How You're Doing Today")
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: metricColumns, spacing: 12) {
                restingHRTile
                hrvTile
                recoveryTile
                vo2MaxTile
                stepsTile
                sleepTile
            }
        }
    }

    private var restingHRTile: some View {
        MetricTileView(
            label: "Resting Heart Rate",
            optionalValue: viewModel.todaySnapshot?.restingHeartRate,
            unit: "bpm",
            trend: nil,
            confidence: nil,
            isLocked: false
        )
    }

    private var hrvTile: some View {
        MetricTileView(
            label: "HRV",
            optionalValue: viewModel.todaySnapshot?.hrvSDNN,
            unit: "ms",
            trend: nil,
            confidence: nil,
            isLocked: false
        )
    }

    private var recoveryTile: some View {
        MetricTileView(
            label: "Recovery",
            optionalValue: viewModel.todaySnapshot?.recoveryHR1m,
            unit: "bpm",
            trend: nil,
            confidence: nil,
            isLocked: false
        )
    }

    private var vo2MaxTile: some View {
        MetricTileView(
            label: "Cardio Fitness",
            optionalValue: viewModel.todaySnapshot?.vo2Max,
            unit: "mL/kg/min",
            decimals: 1,
            trend: nil,
            confidence: nil,
            isLocked: false
        )
    }

    private var stepsTile: some View {
        MetricTileView(
            label: "Steps",
            optionalValue: viewModel.todaySnapshot?.steps,
            unit: "steps",
            trend: nil,
            confidence: nil,
            isLocked: false
        )
    }

    private var sleepTile: some View {
        MetricTileView(
            label: "Sleep",
            optionalValue: viewModel.todaySnapshot?.sleepHours,
            unit: "hrs",
            decimals: 1,
            trend: nil,
            confidence: nil,
            isLocked: false
        )
    }

    // MARK: - Nudge Section

    @ViewBuilder
    private var nudgeSection: some View {
        if let assessment = viewModel.assessment {
            VStack(alignment: .leading, spacing: 12) {
                Text("A Friendly Suggestion")
                    .font(.headline)
                    .foregroundStyle(.primary)

                NudgeCardView(
                    nudge: assessment.dailyNudge,
                    onMarkComplete: {
                        viewModel.markNudgeComplete()
                    }
                )
            }
        }
    }

    // MARK: - Streak Badge

    @ViewBuilder
    private var streakSection: some View {
        let streak = viewModel.profileStreakDays
        if streak > 0 {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streak)-Day Streak")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Keep checking in daily to build your streak.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.orange.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak)-day streak. Keep checking in daily to build your streak.")
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Getting your wellness snapshot ready...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Getting your wellness snapshot ready")
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Double tap to reload your wellness data")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Dashboard - Loaded") {
    DashboardView()
}
