// SubscriptionService.swift
// Thump iOS
//
// StoreKit 2 subscription service that manages product loading, purchasing,
// restoration, and subscription status tracking. Maps App Store product IDs
// to the SubscriptionTier model for feature gating throughout the app.
// Platforms: iOS 17+

import Foundation
import StoreKit
import Combine

// MARK: - Subscription Error

/// Errors specific to subscription operations.
enum SubscriptionError: LocalizedError {
    /// The requested product was not found in the available products list.
    case productNotFound(tier: SubscriptionTier, isAnnual: Bool)

    /// The requested tier/billing combination is not valid (e.g. family + monthly).
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .productNotFound(let tier, let isAnnual):
            let period = isAnnual ? "annual" : "monthly"
            return "Could not find \(tier.displayName) \(period) product. Please try again later."
        case .invalidConfiguration:
            return "The selected subscription configuration is not available."
        }
    }
}
// MARK: - Subscription Service

/// Manages in-app subscriptions using StoreKit 2.
///
/// Loads available products, processes purchases, restores transactions,
/// and continuously monitors `Transaction.updates` to keep the
/// `currentTier` property synchronized with the user's subscription state.
final class SubscriptionService: ObservableObject {

    // MARK: - Published State

    /// The user's current subscription tier based on verified transactions.
    @Published var currentTier: SubscriptionTier = .free

    /// Available subscription products loaded from the App Store.
    @Published var availableProducts: [Product] = []

    /// Whether a purchase is currently in progress.
    @Published var purchaseInProgress: Bool = false

    /// Error from the most recent product-loading attempt, if any.
    @Published var productLoadError: Error?

    // MARK: - Product IDs

    /// All Thump subscription product identifiers.
    private static let productIDs: Set<String> = [
        "com.thump.pro.monthly",
        "com.thump.pro.annual",
        "com.thump.coach.monthly",
        "com.thump.coach.annual",
        "com.thump.family.annual"
    ]

    // MARK: - Private Properties

    /// Task that listens for transaction updates in the background.
    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        // Start listening for transaction updates
        transactionListenerTask = Task { [weak self] in
            await self?.listenForTransactionUpdates()
        }

        // Load initial subscription status
        Task { [weak self] in
            await self?.updateSubscriptionStatus()
        }
    }

    #if DEBUG
    /// Preview instance for SwiftUI previews.
    static var preview: SubscriptionService { SubscriptionService() }
    #endif

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Product Loading

    /// Loads available subscription products from the App Store.
    ///
    /// Populates the `availableProducts` array sorted by price.
    /// Silently handles errors by leaving the array empty.
    func loadProducts() async {
        do {
            let products = try await Product.products(for: Self.productIDs)

            // Sort by price ascending for consistent display
            let sorted = products.sorted { $0.price < $1.price }

            await MainActor.run {
                self.availableProducts = sorted
                self.productLoadError = nil
            }
        } catch {
            debugPrint("[SubscriptionService] Failed to load products: \(error.localizedDescription)")
            await MainActor.run {
                self.productLoadError = error
            }
        }
    }

    // MARK: - Purchasing

    /// Initiates a purchase for the specified product.
    ///
    /// Updates `purchaseInProgress` during the transaction and refreshes
    /// the subscription status upon success.
    ///
    /// - Parameter product: The `Product` to purchase.
    /// - Throws: Any StoreKit purchase error or cancellation.
    func purchase(_ product: Product) async throws {
        await MainActor.run {
            self.purchaseInProgress = true
        }

        defer {
            Task { @MainActor in
                self.purchaseInProgress = false
            }
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerification(verification)
            await transaction.finish()
            await updateSubscriptionStatus()

        case .userCancelled:
            debugPrint("[SubscriptionService] User cancelled purchase.")

        case .pending:
            debugPrint("[SubscriptionService] Purchase pending (e.g., Ask to Buy).")

        @unknown default:
            debugPrint("[SubscriptionService] Unknown purchase result.")
        }
    }

    /// Initiates a purchase for the specified tier and billing period.
    ///
    /// Resolves the tier and billing period to a product ID, finds the
    /// matching `Product` from `availableProducts`, and delegates to
    /// `purchase(_:)`.
    ///
    /// - Parameters:
    ///   - tier: The subscription tier to purchase.
    ///   - isAnnual: Whether to purchase the annual (`true`) or monthly (`false`) variant.
    /// - Throws: `SubscriptionError.productNotFound` if the product is not loaded,
    ///           or any StoreKit error from the underlying purchase.
    func purchase(tier: SubscriptionTier, isAnnual: Bool) async throws {
        // Family plan is annual-only; reject monthly to prevent constructing
        // an invalid product ID ("com.thump.family.monthly" does not exist).
        if tier == .family && !isAnnual {
            throw SubscriptionError.invalidConfiguration
        }

        let period = isAnnual ? "annual" : "monthly"
        let productID = "com.thump.\(tier.rawValue).\(period)"

        guard let product = availableProducts.first(where: { $0.id == productID }) else {
            throw SubscriptionError.productNotFound(tier: tier, isAnnual: isAnnual)
        }

        try await purchase(product)
    }

    // MARK: - Restore Purchases

    /// Restores previously purchased subscriptions.
    ///
    /// Syncs with the App Store to ensure all entitled transactions are
    /// reflected, then updates the subscription status.
    ///
    /// - Throws: Any error from `AppStore.sync()`.
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Subscription Status

    /// Updates the current subscription tier by examining all verified transactions.
    ///
    /// Iterates through `Transaction.currentEntitlements` to find the highest-tier
    /// active subscription. Falls back to `.free` if no active subscriptions exist.
    func updateSubscriptionStatus() async {
        var resolvedTier: SubscriptionTier = .free

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerification(result) else {
                continue
            }

            // Only consider subscription transactions
            if transaction.productType == .autoRenewable {
                let tier = Self.tierForProductID(transaction.productID)
                if Self.tierPriority(tier) > Self.tierPriority(resolvedTier) {
                    resolvedTier = tier
                }
            }
        }

        let finalTier = resolvedTier
        await MainActor.run {
            self.currentTier = finalTier
        }
    }

    // MARK: - Transaction Updates Listener

    /// Continuously listens for transaction updates from StoreKit.
    ///
    /// Handles renewals, revocations, and other transaction state changes
    /// that occur while the app is running or in the background.
    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            guard let transaction = try? checkVerification(result) else {
                debugPrint("[SubscriptionService] Unverified transaction update ignored.")
                continue
            }

            await transaction.finish()
            await updateSubscriptionStatus()
        }
    }

    // MARK: - Verification

    /// Verifies a StoreKit verification result and extracts the transaction.
    ///
    /// - Parameter result: The `VerificationResult` from StoreKit.
    /// - Returns: The verified `Transaction`.
    /// - Throws: `StoreKitError.notEntitled` if verification fails.
    private func checkVerification<T>(
        _ result: VerificationResult<T>
    ) throws -> T {
        switch result {
        case .unverified(_, let error):
            debugPrint("[SubscriptionService] Unverified transaction: \(error.localizedDescription)")
            throw error
        case .verified(let value):
            return value
        }
    }

    // MARK: - Product ID to Tier Mapping

    /// Maps a product identifier to its corresponding `SubscriptionTier`.
    ///
    /// - Parameter productID: The App Store product identifier string.
    /// - Returns: The `SubscriptionTier` for the product, defaulting to `.free`.
    static func tierForProductID(_ productID: String) -> SubscriptionTier {
        switch productID {
        case "com.thump.pro.monthly",
             "com.thump.pro.annual":
            return .pro

        case "com.thump.coach.monthly",
             "com.thump.coach.annual":
            return .coach

        case "com.thump.family.annual":
            return .family

        default:
            return .free
        }
    }

    /// Returns a numeric priority for tier comparison. Higher value = higher tier.
    ///
    /// - Parameter tier: The `SubscriptionTier` to rank.
    /// - Returns: An integer priority value.
    private static func tierPriority(_ tier: SubscriptionTier) -> Int {
        switch tier {
        case .free:   return 0
        case .pro:    return 1
        case .coach:  return 2
        case .family: return 3
        }
    }
}
