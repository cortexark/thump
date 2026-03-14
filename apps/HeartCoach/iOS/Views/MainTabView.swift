// MainTabView.swift
// Thump iOS
//
// Root tab-based navigation for the Thump app. Five tabs:
// Home (Dashboard), Insights, Stress, Trends, Settings.
// The tint color adapts per tab for visual warmth.
// Swipe left/right anywhere on screen to move between tabs.
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

    private let tabCount = 5

    // Raw finger offset — no scaling, just follows the touch directly
    @State private var dragOffset: CGFloat = 0

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
        .onAppear { checkBreatheDeepLink() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            checkBreatheDeepLink()
        }
        .offset(x: dragOffset)
        .highPriorityGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .global)
                .onChanged { value in
                    let h = value.translation.width
                    let v = value.translation.height
                    guard abs(h) > abs(v) * 1.2 else { return }
                    // Resist at edges, free movement between tabs
                    let atEdge = (selectedTab == 0 && h > 0) ||
                                 (selectedTab == tabCount - 1 && h < 0)
                    dragOffset = atEdge ? h * 0.12 : h * 0.45
                }
                .onEnded { value in
                    let h = value.translation.width
                    let v = value.translation.height

                    if abs(h) > abs(v) * 2 && abs(h) > 60 {
                        if h < 0 && selectedTab < tabCount - 1 {
                            // Commit swipe left: slide offset to full width then snap tab
                            withAnimation(.smooth(duration: 0.28)) {
                                dragOffset = 0
                                selectedTab += 1
                            }
                            return
                        } else if h > 0 && selectedTab > 0 {
                            withAnimation(.smooth(duration: 0.28)) {
                                dragOffset = 0
                                selectedTab -= 1
                            }
                            return
                        }
                    }
                    // Not enough to commit — spring back
                    withAnimation(.smooth(duration: 0.22)) {
                        dragOffset = 0
                    }
                }
        )
    }

    // MARK: - Deep Link: Siri "Start Breathing"

    private func checkBreatheDeepLink() {
        let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName)
        guard defaults?.bool(forKey: ThumpSharedKeys.breatheDeepLinkKey) == true else { return }
        defaults?.set(false, forKey: ThumpSharedKeys.breatheDeepLinkKey)
        // Tab 2 is the Stress tab which has the breathing UI
        withAnimation { selectedTab = 2 }
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
