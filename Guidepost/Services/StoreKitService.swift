//
//  StoreKitService.swift
//  Guidepost
//
//  Created by John Gambrell on 2/3/26.
//

import Foundation
import os.log
import StoreKit

// MARK: - StoreKit Service

/// Manages StoreKit 2 subscription products, purchases, and entitlement status
@MainActor
@Observable
final class StoreKitService {
    
    nonisolated private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.gambrell.guidepost", category: "StoreKit")
    
    // MARK: - Published Properties
    
    /// Available subscription products from the App Store
    private(set) var products: [Product] = []
    
    /// Current subscription status
    private(set) var subscriptionStatus: SubscriptionStatus = .trial
    
    /// Whether products are currently being loaded
    private(set) var isLoadingProducts = false
    
    /// Whether a purchase is in progress
    private(set) var isPurchasing = false
    
    /// Error message to display to user
    var errorMessage: String?
    
    // MARK: - Computed Properties
    
    /// Current subscription plan
    var currentPlan: SubscriptionPlan {
        subscriptionStatus.plan
    }
    
    /// Whether user has an active Pro subscription
    var isSubscribed: Bool {
        subscriptionStatus.plan == .pro && subscriptionStatus.isActive
    }
    
    /// Monthly subscription product
    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.monthlyPro.rawValue }
    }
    
    /// Yearly subscription product
    var yearlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.yearlyPro.rawValue }
    }
    
    // MARK: - Private Properties
    
    private var transactionListener: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        // Start listening for transaction updates
        transactionListener = listenForTransactions()
        
        // Only load products on init - subscription status is checked when user signs in
        // This prevents showing previous Apple ID's subscription to new guest users
        Task {
            await loadProducts()
        }
    }
    
    /// Cancel the transaction listener when service is deallocated
    /// Note: We capture the task in a local variable to avoid actor isolation issues
    func cleanup() {
        transactionListener?.cancel()
        transactionListener = nil
    }
    
    /// Reset subscription status to trial (called on sign out)
    /// This ensures a new user/guest doesn't see the previous user's subscription status
    func resetSubscriptionStatus() {
        subscriptionStatus = .trial
        Self.logger.info("Subscription status reset to Trial")
    }
    
    // MARK: - Product Loading
    
    /// Load subscription products from the App Store
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        
        isLoadingProducts = true
        errorMessage = nil
        defer { isLoadingProducts = false }
        
        let requestedIDs = SubscriptionProduct.allIdentifiers
        Self.logger.info("Loading products for IDs: \(requestedIDs.sorted().joined(separator: ", "))")
        
        do {
            let storeProducts = try await Product.products(for: requestedIDs)
            
            if storeProducts.isEmpty {
                Self.logger.error("Product.products(for:) returned 0 products for IDs: \(requestedIDs.sorted().joined(separator: ", ")). Verify products are configured and approved in App Store Connect.")
                errorMessage = "No subscription products found. Please ensure your App Store account is set up correctly, or try again later."
                return
            }
            
            products = storeProducts.sorted { first, _ in
                first.id == SubscriptionProduct.monthlyPro.rawValue
            }
            
            Self.logger.info("Loaded \(self.products.count) products successfully")
            for product in products {
                Self.logger.info("  Product: \(product.id) — \(product.displayPrice)")
            }
        } catch {
            Self.logger.error("Failed to load products: \(error.localizedDescription)")
            errorMessage = "Failed to load subscription options: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Subscription Status
    
    /// Check current subscription entitlement status
    func checkSubscriptionStatus() async {
        // First, try to get detailed subscription status from products
        for product in products {
            guard let subscription = product.subscription else { continue }
            
            do {
                let statuses = try await subscription.status
                
                for status in statuses {
                    guard case .verified(let renewalInfo) = status.renewalInfo,
                          case .verified(let transaction) = status.transaction else {
                        continue
                    }
                    
                    // Check if this subscription is active
                    let isActive = status.state == .subscribed || status.state == .inGracePeriod
                    
                    if isActive && SubscriptionProduct.allIdentifiers.contains(transaction.productID) {
                        let willAutoRenew = renewalInfo.willAutoRenew
                        
                        let subscriptionStatus = SubscriptionStatus(
                            plan: .pro,
                            expirationDate: transaction.expirationDate,
                            willRenew: willAutoRenew
                        )
                        self.subscriptionStatus = subscriptionStatus
                        
                        Self.logger.info("Active subscription: \(transaction.productID), expires: \(transaction.expirationDate?.description ?? "never"), willRenew: \(willAutoRenew)")
                        
                        return
                    }
                }
            } catch {
                Self.logger.error("Error checking subscription status: \(error.localizedDescription)")
            }
        }
        
        // Fallback: Check currentEntitlements if products aren't loaded yet
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            // Check if this is one of our subscription products
            if SubscriptionProduct.allIdentifiers.contains(transaction.productID) {
                let status = SubscriptionStatus(
                    plan: .pro,
                    expirationDate: transaction.expirationDate,
                    willRenew: true
                )
                subscriptionStatus = status
                
                Self.logger.info("Active subscription (fallback): \(transaction.productID), expires: \(transaction.expirationDate?.description ?? "never")")
                
                return
            }
        }
        
        subscriptionStatus = .trial
        Self.logger.info("No active subscription — using Trial plan")
    }
    
    // MARK: - Purchase
    
    /// Purchase a subscription product
    /// - Parameter product: The product to purchase
    /// - Returns: Whether the purchase was successful
    @discardableResult
    func purchase(_ product: Product) async throws -> Bool {
        guard !isPurchasing else { return false }
        
        isPurchasing = true
        defer { isPurchasing = false }
        
        Self.logger.info("Attempting purchase: \(product.id)")
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                guard case .verified(let transaction) = verification else {
                    throw SubscriptionError.verificationFailed
                }
                
                // Finish the transaction
                await transaction.finish()
                
                // Update subscription status
                await checkSubscriptionStatus()
                
                Self.logger.info("Purchase successful: \(product.id)")
                return true
                
            case .userCancelled:
                Self.logger.info("Purchase cancelled by user")
                throw SubscriptionError.purchaseCancelled
                
            case .pending:
                Self.logger.info("Purchase pending (Ask to Buy)")
                return false
                
            @unknown default:
                return false
            }
        } catch let error as SubscriptionError {
            throw error
        } catch {
            Self.logger.error("Purchase error: \(error.localizedDescription)")
            throw SubscriptionError.unknown(error)
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Restore previous purchases
    func restorePurchases() async throws {
        Self.logger.info("Restoring purchases...")
        try await AppStore.sync()
        await checkSubscriptionStatus()
        Self.logger.info("Restore complete. Current plan: \(self.currentPlan.displayName)")
    }
    
    // MARK: - Manage Subscription
    
    /// Open the App Store subscription management page
    func openManageSubscriptions() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        
        do {
            try await AppStore.showManageSubscriptions(in: windowScene)
        } catch {
            Self.logger.error("Failed to open manage subscriptions: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Transaction Listener
    
    /// Listen for transaction updates (renewals, refunds, etc.)
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }
                
                await transaction.finish()
                await self?.checkSubscriptionStatus()
                Self.logger.info("Transaction update: \(transaction.productID)")
            }
        }
    }
}

// MARK: - Product Extensions

extension Product {
    /// Formatted savings percentage compared to monthly pricing
    func yearlySavingsPercentage(comparedTo monthlyProduct: Product?) -> Int? {
        guard let monthly = monthlyProduct,
              let yearlySubscription = self.subscription,
              let monthlySubscription = monthly.subscription,
              yearlySubscription.subscriptionPeriod.unit == .year,
              monthlySubscription.subscriptionPeriod.unit == .month else {
            return nil
        }
        
        // Convert Decimal to Double for calculation
        let yearlyPrice = NSDecimalNumber(decimal: self.price).doubleValue
        let monthlyAnnualized = NSDecimalNumber(decimal: monthly.price).doubleValue * 12
        
        guard monthlyAnnualized > 0 else { return nil }
        
        let savings = ((monthlyAnnualized - yearlyPrice) / monthlyAnnualized) * 100
        return Int(savings.rounded())
    }
}
