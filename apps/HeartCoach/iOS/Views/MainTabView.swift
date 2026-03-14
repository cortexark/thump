// MainTabView.swift
// Thump iOS
//
// Root tab-based navigation for the Thump app. Five tabs:
// Home (Dashboard), Insights, Stress, Trends, Settings.
// The tint color adapts per tab for visual warmth.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - MainTabView

struct MainTabView: View {

    @State var selectedTab: Int = {
        // Support launch argument: -startTab N
        if let idx = CommandLine.arguments.firstIndex(of: "-startTab"),
           idx + 1 < CommandLine.arguments.count,
           let tab = Int(CommandLine.arguments[idx + 1]) {
            return tab
        }
        return 0  // Start on Home (Dashboard)
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            dashboardTab
            insightsTab
            stressTab
            trendsTab
            settingsTab
        }
        .tint(tabTint)
        .onChange(of: selectedTab) { oldTab, newTab in
            InteractionLog.tabSwitch(from: oldTab, to: newTab)
        }
    }

    // MARK: - Dynamic Tab Tint

    private var tabTint: Color {
        switch selectedTab {
        case 0: return Color(hex: 0xF97316) // warm coral for home
        case 1: return Color(hex: 0x8B5CF6) // purple for insights
        case 2: return Color(hex: 0xEF4444) // red for stress
        case 3: return Color(hex: 0x3B82F6) // blue for trends
        case 4: return .secondary            // neutral for settings
        default: return Color(hex: 0xF97316)
        }
    }

    // MARK: - Tabs

    private var dashboardTab: some View {
        DashboardView(selectedTab: $selectedTab)
            .tabItem {
                Label("Home", systemImage: "heart.circle.fill")
            }
            .tag(0)
    }

    private var insightsTab: some View {
        InsightsView()
            .tabItem {
                Label("Insights", systemImage: "sparkles")
            }
            .tag(1)
    }

    private var stressTab: some View {
        StressView()
            .tabItem {
                Label("Stress", systemImage: "bolt.heart.fill")
            }
            .tag(2)
    }

    private var trendsTab: some View {
        TrendsView()
            .tabItem {
                Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(3)
    }

    private var settingsTab: some View {
        SettingsView()
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(4)
    }

    // MARK: - Buddy Style Gallery (temporary — remove after style selection)

    private var buddyGalleryTab: some View {
        BuddyStyleGalleryScreen()
            .tabItem {
                Label("Buddy", systemImage: "sparkle")
            }
            .tag(10)
    }
}

// MARK: - Preview

#Preview("Main Tab View") {
    MainTabView()
}
