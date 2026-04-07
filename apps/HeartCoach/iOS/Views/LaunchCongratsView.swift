// LaunchCongratsView.swift
// Thump iOS
//
// Grandfathered launch-access screen shown for users who were enrolled
// in the original complimentary first-year offer.
// Platforms: iOS 17+

import SwiftUI

// MARK: - Launch Congratulations View

/// Full-screen launch-access view shown for grandfathered users,
/// informing them that their complimentary Coach access is still active.
struct LaunchCongratsView: View {

    /// Called when the user taps "Get Started" to dismiss and continue.
    let onContinue: () -> Void

    // MARK: - Animation State

    @State private var showContent = false
    @State private var showButton = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.pink.opacity(0.15),
                    Color.purple.opacity(0.1),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Gift icon
                Image(systemName: "gift.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(showContent ? 1.0 : 0.5)
                    .opacity(showContent ? 1 : 0)

                VStack(spacing: 16) {
                    Text("Congratulations!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Grandfathered Launch Access")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("You joined during the launch period, so Coach stays unlocked for your complimentary first year.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

                // Feature highlights
                VStack(alignment: .leading, spacing: 14) {
                    featureRow(icon: "heart.text.clipboard.fill", text: "Heart trend analysis & anomaly alerts")
                    featureRow(icon: "brain.head.profile.fill", text: "Stress, readiness & bio age engines")
                    featureRow(icon: "figure.run", text: "Coaching insights & zone analysis")
                    featureRow(icon: "bell.badge.fill", text: "Smart wellness nudges")
                }
                .padding(.horizontal, 40)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

                Spacer()

                // Get Started button
                Button {
                    onContinue()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
                .padding(.horizontal, 32)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)

                Spacer()
                    .frame(height: 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                showButton = true
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.pink)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}
