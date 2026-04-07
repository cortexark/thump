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
    @State private var healthKitErrorMessage: String?

    /// Tracks whether HealthKit access has been granted (or at least requested).
    @State private var healthKitGranted: Bool = false

    /// Whether the user has accepted the health disclaimer.
    @State private var disclaimerAccepted: Bool = false

    /// Selected biological sex for metric personalization.
    @State private var selectedSex: BiologicalSex = .notSet

    /// A quick first insight shown after HealthKit access is granted.
    @State private var firstInsight: String?

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch currentPage {
                    case 0:  welcomePage
                    case 1:  healthKitPage
                    case 2:  disclaimerPage
                    case 3:  profilePage
                    default: welcomePage
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                // Consume horizontal drag gestures to prevent any swipe navigation
                .gesture(DragGesture())
                .onAppear {
                    InteractionLog.pageView("Onboarding")
                }
                // Safety gate: prevent skipping HealthKit page without granting
                .onChange(of: currentPage) { _, newPage in
                    if newPage >= 2 && !healthKitGranted {
                        currentPage = 1
                    }
                }

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
        case 2: [Color(red: 0.55, green: 0.22, blue: 0.08), Color(red: 0.72, green: 0.35, blue: 0.10)]
        default: [.green.opacity(0.65), .teal.opacity(0.55)]
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
                "Your Wellness Companion.\nTrack trends, "
                    + "get friendly nudges, and explore your fitness data over time."
            )
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            nextButton(label: "Get Started") {
                InteractionLog.log(.buttonTap, element: "get_started_button", page: "Onboarding", details: "page=0")
                withAnimation { currentPage = 1 }
            }
            .accessibilityIdentifier("onboarding_next_button")

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
                "Thump needs read-only access to the following "
                    + "Apple Health data to generate your "
                    + "personalized wellness insights."
            )
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 6) {
                Text("We'll request access to:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 40)

                featureRow(icon: "heart.fill", text: "Heart Rate")
                featureRow(icon: "waveform.path.ecg", text: "Resting Heart Rate & HRV")
                featureRow(icon: "lungs.fill", text: "VO2 Max (Cardio Fitness)")
                featureRow(icon: "figure.walk", text: "Steps")
                featureRow(icon: "figure.run", text: "Exercise Minutes & Workouts")
                featureRow(icon: "bed.double.fill", text: "Sleep Analysis")
                featureRow(icon: "scalemass.fill", text: "Body Weight")
                featureRow(icon: "person.fill", text: "Biological Sex & Date of Birth")
            }

            Spacer()

            if healthKitGranted {
                grantedBadge

                if let insight = firstInsight {
                    Text(insight)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .transition(.opacity.combined(with: .scale))
                }
            } else {
                nextButton(label: "Grant Access") {
                    InteractionLog.log(.buttonTap, element: "healthkit_grant_button", page: "Onboarding")
                    requestHealthKitAccess()
                }
                .accessibilityIdentifier("onboarding_healthkit_grant_button")
                .disabled(isRequestingHealthKit)
                .opacity(isRequestingHealthKit ? 0.6 : 1.0)
            }

            if let errorMsg = healthKitErrorMessage {
                Text(errorMsg)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
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
                "Thump is a wellness tool, not a medical device. "
                    + "It does not diagnose, treat, cure, or prevent any disease. "
                    + "Always consult a healthcare professional before "
                    + "making changes to your health routine. "
                    + "For emergencies, call 911."
            )
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Toggle("I understand this is not medical advice", isOn: $disclaimerAccepted)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .tint(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 8)
                .accessibilityIdentifier("onboarding_disclaimer_toggle")
                .onChange(of: disclaimerAccepted) { _, newValue in
                    InteractionLog.log(.toggleChange, element: "disclaimer_toggle", page: "Onboarding", details: "accepted=\(newValue)")
                }

            Spacer()

            nextButton(label: "Continue") {
                InteractionLog.log(.buttonTap, element: "continue_button", page: "Onboarding", details: "page=2")
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
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)

            Text("Tell us about yourself")
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
                .accessibilityIdentifier("onboarding_name_field")
                .onChange(of: userName) { _, newValue in
                    InteractionLog.log(.textInput, element: "name_field", page: "Onboarding", details: "length=\(newValue.count)")
                }

            // Biological sex — show auto-detected badge or manual picker as fallback
            VStack(spacing: 8) {
                if selectedSex != .notSet && healthKitGranted {
                    // Already read from HealthKit — just confirm it
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Biological sex: \(selectedSex.displayLabel)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.9))
                        Text("(from Apple Health)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(
                        Capsule()
                            .fill(.white.opacity(0.15))
                    )
                } else {
                    // HealthKit didn't provide it — show manual picker
                    Text("Biological sex (for metric accuracy)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(spacing: 10) {
                        ForEach(BiologicalSex.allCases, id: \.self) { sex in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedSex = sex
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: sex.icon)
                                        .font(.system(size: 13))
                                    Text(sex.displayLabel)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(selectedSex == sex ? .pink : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(selectedSex == sex ? .white : .white.opacity(0.2))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            nextButton(label: "Start Using Thump") {
                InteractionLog.log(.buttonTap, element: "finish_button", page: "Onboarding")
                completeOnboarding()
            }
            .accessibilityIdentifier("onboarding_finish_button")
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

                    // Auto-read biological sex and DOB from HealthKit
                    let hkSex = healthKitService.readBiologicalSex()
                    if hkSex != .notSet {
                        selectedSex = hkSex
                    }
                    if let hkDOB = healthKitService.readDateOfBirth() {
                        localStore.profile.dateOfBirth = hkDOB
                        localStore.saveProfile()
                    }
                }
                // Fetch a quick first insight, then auto-advance
                Task {
                    do {
                        let snapshot = try await healthKitService.fetchTodaySnapshot()
                        await MainActor.run {
                            if let rhr = snapshot.restingHeartRate {
                                firstInsight = "Your resting heart rate is \(Int(rhr)) bpm today"
                            } else if let hrv = snapshot.hrvSDNN {
                                firstInsight = "Your HRV is \(Int(hrv)) ms today"
                            } else if let steps = snapshot.steps {
                                firstInsight = "\(Int(steps)) steps logged today"
                            }
                        }
                    } catch {
                        // Silently fail — insight is optional
                    }
                    // Auto-advance after brief pause to show insight
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await MainActor.run {
                        withAnimation { currentPage = 2 }
                    }
                }
            } catch {
                await MainActor.run {
                    isRequestingHealthKit = false
                    healthKitGranted = false
                    healthKitErrorMessage = "Unable to access Health data. "
                        + "Please enable it in Settings → Privacy → Health."
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
        profile.biologicalSex = selectedSex
        localStore.profile = profile
        localStore.saveProfile()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Onboarding Flow") {
    OnboardingView()
        .environmentObject(LocalStore.preview)
        .environmentObject(HealthKitService.preview)
}
#endif
