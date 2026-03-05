// MainTabView.swift
// Thump iOS
//
// Root tab-based navigation for the Thump app. Provides four primary tabs:
// Dashboard, Trends, Insights, and Settings. Each tab lazily instantiates its
// destination view. Services are passed through the environment.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - MainTabView

/// The primary navigation container for Thump.
///
/// Uses a `TabView` with four tabs corresponding to the app's core sections.
/// Service dependencies are expected to be injected as `@EnvironmentObject`
/// values from the app root.
struct MainTabView: View {

    // MARK: - State

    /// The currently selected tab index.
    @State var selectedTab: Int = 0

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            dashboardTab
            trendsTab
            insightsTab
            settingsTab
        }
        .tint(.pink)
    }

    // MARK: - Tabs

    private var dashboardTab: some View {
        DashboardView()
            .tabItem {
                Label("Dashboard", systemImage: "heart.fill")
            }
            .tag(0)
    }

    private var trendsTab: some View {
        TrendsView()
            .tabItem {
                Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(1)
    }

    private var insightsTab: some View {
        InsightsView()
            .tabItem {
                Label("Insights", systemImage: "lightbulb.fill")
            }
            .tag(2)
    }

    private var settingsTab: some View {
        SettingsView()
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
    }
}

// MARK: - Preview

#Preview("Main Tab View") {
    MainTabView()
}
