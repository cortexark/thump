// OnboardingView.swift
// Thump iOS
//
// A four-step onboarding flow presented to new users. Guides through:
// 1. Welcome — introducing the app's purpose.
// 2. HealthKit — requesting health data permissions.
// 3. Disclaimer — health disclaimer acknowledgement.
// 4. Profile — capturing the user's display name.
//
// On completion the user profile is marked as onboarded and persisted
// through the LocalStore environment object.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - OnboardingView

/// Full-screen onboarding presented before the main app experience.
///
/// Uses a paged `TabView` with a gradient background that shifts color
/// across the four steps. The final step persists the profile and
/// dismisses the flow.
struct OnboardingView: View {

    // MARK: - Environment

    /// Persistent local storage for user profile data.
    @EnvironmentObject var localStore: LocalStore

    /// HealthKit data access service.
    @EnvironmentObject var healthKitService: HealthKitService

    // MARK: - State

    /// The current page index (0-based).
    @State var currentPage: Int = 0

    /// The user's display name entered on the final page.
    @State var userName: String = ""

    /// Tracks whether a HealthKit authorization request is in-flight.
    @State private var isRequestingHealthKit: Bool = false

    /// Tracks whether HealthKit access has been granted (or at least requested).
    @State private var healthKitGranted: Bool = false

    /// Whether the user has accepted the health disclaimer.
    @State private var disclaimerAccepted: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    healthKitPage.tag(1)
                    disclaimerPage.tag(2)
                    profilePage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                pageIndicator
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Background

    /// A shifting gradient that tints warmer as the user progresses.
    private var backgroundGradient: some View {
        let colors: [Color] = switch currentPage {
        case 0: [.pink.opacity(0.7), .purple.opacity(0.5)]
        case 1: [.blue.opacity(0.6), .cyan.opacity(0.4)]
        case 2: [.orange.opacity(0.6), .yellow.opacity(0.4)]
        default: [.green.opacity(0.5), .teal.opacity(0.4)]
        }
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(.easeInOut(duration: 0.5), value: currentPage)
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.white : Color.white.opacity(0.4))
                    .frame(width: index == currentPage ? 10 : 8,
                           height: index == currentPage ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)

            Text("Welcome to Thump")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(
                "Your Heart Training Buddy.\nTrack trends, "
                    + "get friendly nudges, and explore your fitness data over time."
            )
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            nextButton(label: "Get Started") {
                withAnimation { currentPage = 1 }
            }

            Spacer()
                .frame(height: 16)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Page 2: HealthKit Permissions

    private var healthKitPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)

            Text("Connect Your Health Data")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(
                "Thump reads your heart rate, HRV, recovery, activity, "
                    + "and sleep data from Apple Health to generate "
                    + "personalized insights for your training."
            )
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            featureRow(icon: "waveform.path.ecg", text: "Resting Heart Rate & HRV")
            featureRow(icon: "figure.run", text: "Activity & Workout Minutes")
            featureRow(icon: "bed.double.fill", text: "Sleep Duration")

            Spacer()

            if healthKitGranted {
                grantedBadge
            } else {
                nextButton(label: "Grant Access") {
                    requestHealthKitAccess()
                }
                .disabled(isRequestingHealthKit)
                .opacity(isRequestingHealthKit ? 0.6 : 1.0)
            }

            if healthKitGranted {
                nextButton(label: "Continue") {
                    withAnimation { currentPage = 2 }
                }
            }

            Spacer()
                .frame(height: 16)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Page 3: Health Disclaimer

    private var disclaimerPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.text.square")
                .font(.system(size: 80))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)

            Text("Before We Start")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(
                "Thump is your heart training buddy — not a medical device. "
                    + "It does not diagnose, treat, cure, or prevent any disease. "
                    + "Always consult a qualified healthcare professional before "
                    + "making changes to your health routine. "
                    + "For medical emergencies, call 911."
            )
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Toggle("I understand and acknowledge", isOn: $disclaimerAccepted)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .tint(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 8)

            Spacer()

            nextButton(label: "Continue") {
                withAnimation { currentPage = 3 }
            }
            .disabled(!disclaimerAccepted)
            .opacity(!disclaimerAccepted ? 0.5 : 1.0)

            Spacer()
                .frame(height: 16)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Page 4: Profile

    private var profilePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)

            Text("What should we call you?")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            TextField("Your name", text: $userName)
                .textFieldStyle(.plain)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.vertical, 14)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white.opacity(0.2))
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 40)

            Spacer()

            nextButton(label: "Let's Go") {
                completeOnboarding()
            }
            .disabled(userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)

            Spacer()
                .frame(height: 16)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Reusable Subviews

    /// A large, pill-shaped action button with a white foreground.
    private func nextButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.pink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .padding(.horizontal, 24)
    }

    /// A horizontal row with an SF Symbol and descriptive text.
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    /// A checkmark badge displayed after HealthKit authorization.
    private var grantedBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
            Text("Access Granted")
                .font(.headline)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(.white.opacity(0.2), in: Capsule())
    }

    // MARK: - Actions

    /// Requests HealthKit authorization via the injected service.
    private func requestHealthKitAccess() {
        isRequestingHealthKit = true
        Task {
            do {
                try await healthKitService.requestAuthorization()
                await MainActor.run {
                    isRequestingHealthKit = false
                    healthKitGranted = true
                }
            } catch {
                await MainActor.run {
                    isRequestingHealthKit = false
                    healthKitGranted = false
                }
            }
        }
    }

    /// Persists the user profile and marks onboarding as complete.
    private func completeOnboarding() {
        var profile = localStore.profile
        profile.displayName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.joinDate = Date()
        profile.onboardingComplete = true
        localStore.profile = profile
        localStore.saveProfile()
    }
}

// MARK: - Preview

#Preview("Onboarding Flow") {
    OnboardingView()
        .environmentObject(LocalStore.preview)
        .environmentObject(HealthKitService.preview)
}
