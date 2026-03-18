// MainTabView.swift
// Thump iOS
//
// Root tab-based navigation for the Thump app.
//
// Layout variants:
//   useNewTabLayout = false (default): 5 tabs — Home, Insights, Stress, Trends, Settings.
//   useNewTabLayout = true           : 3 tabs — Today, Trends, You.
//                                     (Design system §4 — "3-Tab Model")
//
// The 3-tab layout is behind a UserDefaults feature flag so existing navigation,
// accessibility identifiers, and test selectors remain intact.
// Swipe left/right anywhere on screen to move between tabs.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - MainTabView

struct MainTabView: View {

    /// Feature flag: when true, uses the new 3-tab "Today / Trends / You" layout.
    /// Controlled via UserDefaults key "useNewTabLayout" (e.g. from Settings or a launch arg).
    @AppStorage("useNewTabLayout") private var useNewTabLayout: Bool = false

    @State var selectedTab: Int = {
        // Support launch argument: -startTab N
        if let idx = CommandLine.arguments.firstIndex(of: "-startTab"),
           idx + 1 < CommandLine.arguments.count,
           let tab = Int(CommandLine.arguments[idx + 1]) {
            return tab
        }
        return 0  // Start on Home / Today
    }()

    private var tabCount: Int { useNewTabLayout ? 3 : 5 }

    // Raw finger offset — no scaling, just follows the touch directly
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        if useNewTabLayout {
            newThreeTabView
        } else {
            legacyFiveTabView
        }
    }

    // MARK: - New 3-Tab Layout (Design System §4)

    private var newThreeTabView: some View {
        TabView(selection: $selectedTab) {
            todayTab
            newTrendsTab
            youTab
        }
        .tint(newTabTint)
        .onChange(of: selectedTab) { oldTab, newTab in
            InteractionLog.tabSwitch(from: oldTab, to: newTab)
        }
        .onAppear { checkBreatheDeepLink() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            checkBreatheDeepLink()
        }
        .offset(x: dragOffset)
        .simultaneousGesture(swipeGesture)
    }

    // MARK: - Legacy 5-Tab Layout (default — preserves all existing navigation)

    private var legacyFiveTabView: some View {
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
        .simultaneousGesture(swipeGesture)
    }

    // MARK: - Shared Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .global)
            .onChanged { value in
                let h = value.translation.width
                let v = value.translation.height
                guard abs(h) > abs(v) * 2.0 else { return }
                let atEdge = (selectedTab == 0 && h > 0) ||
                             (selectedTab == tabCount - 1 && h < 0)
                dragOffset = atEdge ? h * 0.12 : h * 0.45
            }
            .onEnded { value in
                let h = value.translation.width
                let v = value.translation.height
                if abs(h) > abs(v) * 2 && abs(h) > 60 {
                    if h < 0 && selectedTab < tabCount - 1 {
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
                withAnimation(.smooth(duration: 0.22)) {
                    dragOffset = 0
                }
            }
    }

    // MARK: - Deep Link: Siri "Start Breathing"

    private func checkBreatheDeepLink() {
        let defaults = UserDefaults(suiteName: ThumpSharedKeys.suiteName)
        guard defaults?.bool(forKey: ThumpSharedKeys.breatheDeepLinkKey) == true else { return }
        defaults?.set(false, forKey: ThumpSharedKeys.breatheDeepLinkKey)
        // Tab 2 is the Stress tab which has the breathing UI
        withAnimation { selectedTab = 2 }
    }

    // MARK: - Dynamic Tab Tint (Legacy 5-tab)

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

    // MARK: - Dynamic Tab Tint (New 3-tab)

    private var newTabTint: Color {
        switch selectedTab {
        case 0: return Color(hex: 0xEAB308)  // Gold — Today (Thriving state color)
        case 1: return Color(hex: 0x3B82F6)  // Blue — Trends
        case 2: return .secondary             // Neutral — You
        default: return Color(hex: 0xEAB308)
        }
    }

    // MARK: - Legacy 5-Tab Definitions

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

    // MARK: - New 3-Tab Definitions (Design System §4)

    /// Tab 1 — Today: Dashboard (Hero + Mission + Driving signals + Check-in)
    /// Stress content is surfaced here as the Mission sentence + Layer 2 driving signals.
    private var todayTab: some View {
        DashboardView(selectedTab: $selectedTab)
            .tabItem {
                Label("Today", systemImage: "house.fill")
            }
            .tag(0)
            .accessibilityIdentifier("tab_today")
    }

    /// Tab 2 — Trends: All charts, metrics, correlations, stress heatmap, insights.
    /// Consolidates the old Stress + Trends + Insights tabs.
    private var newTrendsTab: some View {
        TrendsView()
            .tabItem {
                Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(1)
            .accessibilityIdentifier("tab_trends")
    }

    /// Tab 3 — You: Profile, Bio Age, Readiness Fingerprint, Settings.
    /// Consolidates the old Insights (educational) + Settings tabs.
    private var youTab: some View {
        SettingsView()
            .tabItem {
                Label("You", systemImage: "person.fill")
            }
            .tag(2)
            .accessibilityIdentifier("tab_you")
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
