// PaywallView.swift
// Thump iOS
//
// Subscription paywall presented modally. Features a gradient hero section,
// a single Coach plan card, a free-vs-paid comparison, and legal links.
// Integrates with SubscriptionService for purchase and restore flows.
//
// Platforms: iOS 17+

import SwiftUI

// MARK: - PaywallView

/// Full-screen subscription paywall with the public Coach plan and purchase actions.
///
/// Presents a single paid plan with monthly and annual billing options.
/// Restore purchases and legal links are provided at the bottom.
struct PaywallView: View {

    // MARK: - Environment

    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) var dismiss

    // MARK: - State

    /// Whether the user is viewing annual pricing (true) or monthly (false).
    @State var isAnnual: Bool = true

    /// Tracks an in-flight purchase or restore operation.
    @State private var isPurchasing: Bool = false

    /// Error message from a failed purchase attempt.
    @State private var purchaseError: String?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    billingToggle
                    pricingCards
                    featureComparison
                    restoreAndLegal
                }
            }
            .background(Color(.systemGroupedBackground))
            .onAppear { InteractionLog.pageView("Paywall") }
            .task {
                // PERF-2: Load product catalog on demand when paywall appears
                if subscriptionService.availableProducts.isEmpty {
                    await subscriptionService.loadProducts()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        InteractionLog.log(.buttonTap, element: "close", page: "Paywall")
                        dismiss()
                    }
                }
            }
            .alert("Purchase Error", isPresented: Binding<Bool>(
                get: { purchaseError != nil },
                set: { if !$0 { purchaseError = nil } }
            )) {
                Button("OK") { purchaseError = nil }
            } message: {
                if let error = purchaseError {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack {
            LinearGradient(
                colors: [.pink, .purple.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 16) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                Text("Unlock Coach")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text(
                    "Go beyond the daily snapshot with the full dashboard, "
                        + "weekly reviews, deeper trends, and shareable wellness summaries."
                )
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.vertical, 40)
        }
    }

    // MARK: - Billing Toggle

    private var billingToggle: some View {
        VStack(spacing: 8) {
            Picker("Billing", selection: $isAnnual) {
                Text("Monthly").tag(false)
                Text("Annual").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)

            if isAnnual {
                Text("Annual saves about 50% compared with monthly")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .fontWeight(.medium)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Pricing Cards

    private var pricingCards: some View {
        coachCard
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var coachCard: some View {
        let tier = SubscriptionTier.merchandisedTier
        let accentColor = Color.purple
        let price = isAnnual ? tier.annualPrice : tier.monthlyPrice
        let period = isAnnual ? "/year" : "/mo"
        let monthlyEquivalent = isAnnual ? tier.annualPrice / 12 : tier.monthlyPrice

        return VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(tier.displayName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        Text(isAnnual ? "Best Value" : "Monthly")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(accentColor, in: Capsule())
                    }

                    Text(
                        isAnnual
                            ? "$\(String(format: "%.2f", monthlyEquivalent))/mo billed yearly"
                            : "Full dashboard, weekly reviews, and PDF summaries"
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.2f", price))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(accentColor)

                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(tier.features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(accentColor)
                            .padding(.top, 2)

                        Text(feature)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Button {
                InteractionLog.log(.buttonTap, element: "subscribe_\(tier.rawValue)", page: "Paywall", details: "annual=\(isAnnual)")
                subscribe(to: tier)
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isAnnual ? "Start Coach Annual" : "Start Coach Monthly")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    AnyShapeStyle(accentColor),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            }
            .disabled(isPurchasing)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    accentColor.opacity(0.4),
                    lineWidth: 2
                )
        )
    }

    // MARK: - Feature Comparison

    private var featureComparison: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Free vs Coach")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                comparisonHeader
                Divider()
                comparisonRow(feature: "Daily wellness snapshot", free: true, coach: true)
                Divider()
                comparisonRow(feature: "Basic trend view", free: true, coach: true)
                Divider()
                comparisonRow(feature: "Full metrics dashboard", free: false, coach: true)
                Divider()
                comparisonRow(feature: "Personalized nudges", free: false, coach: true)
                Divider()
                comparisonRow(feature: "Stress and anomaly context", free: false, coach: true)
                Divider()
                comparisonRow(feature: "Weekly reviews", free: false, coach: true)
                Divider()
                comparisonRow(feature: "PDF wellness summaries", free: false, coach: true)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
    }

    private var comparisonHeader: some View {
        HStack {
            Text("Feature")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Free")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 52)

            Text("Coach")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.purple)
                .frame(width: 56)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
    }

    private func comparisonRow(
        feature: String,
        free: Bool,
        coach: Bool
    ) -> some View {
        HStack {
            Text(feature)
                .font(.caption)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            checkOrCross(free).frame(width: 52)
            checkOrCross(coach, color: .purple).frame(width: 56)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func checkOrCross(_ included: Bool, color: Color = .green) -> some View {
        Image(systemName: included ? "checkmark.circle.fill" : "minus.circle")
            .font(.caption)
            .foregroundStyle(included ? color : .secondary.opacity(0.4))
    }

    // MARK: - Restore & Legal

    private var restoreAndLegal: some View {
        VStack(spacing: 14) {
            Button {
                InteractionLog.log(.buttonTap, element: "restore_purchases", page: "Paywall")
                restorePurchases()
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundStyle(.pink)
            }
            .disabled(isPurchasing)

            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    if let termsURL = URL(string: "https://thump.app/terms") {
                        Link("Terms of Service", destination: termsURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("|")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.5))

                    if let privacyURL = URL(string: "https://thump.app/privacy") {
                        Link("Privacy Policy", destination: privacyURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(
                    "Payment will be charged to your Apple ID account at "
                        + "confirmation of purchase. Subscriptions automatically "
                        + "renew unless canceled at least 24 hours before the "
                        + "end of the current period."
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 28)
    }

    // MARK: - Actions

    /// Initiates a subscription purchase for the given tier.
    private func subscribe(to tier: SubscriptionTier) {
        isPurchasing = true
        Task {
            do {
                try await subscriptionService.purchase(tier: tier, isAnnual: isAnnual)
                await MainActor.run {
                    isPurchasing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    purchaseError = error.localizedDescription
                }
            }
        }
    }

    /// Restores previous purchases.
    private func restorePurchases() {
        isPurchasing = true
        Task {
            do {
                try await subscriptionService.restorePurchases()
                await MainActor.run {
                    isPurchasing = false
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    purchaseError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Paywall") {
    PaywallView()
        .environmentObject(SubscriptionService())
}
