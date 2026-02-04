//
//  StoreKitService.swift
//  Guidepost
//
//  Created by John Gambrell on 2/3/26.
//

import Foundation
import StoreKit

// MARK: - StoreKit Service

/// Manages StoreKit 2 subscription products, purchases, and entitlement status
@MainActor
@Observable
final class StoreKitService {
    
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
        
        #if DEBUG
        print("🛒 Subscription status reset to Trial")
        #endif
    }
    
    // MARK: - Product Loading
    
    /// Load subscription products from the App Store
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        
        do {
            let storeProducts = try await Product.products(for: SubscriptionProduct.allIdentifiers)
            
            // Sort products: monthly first, then yearly
            products = storeProducts.sorted { first, second in
                if first.id == SubscriptionProduct.monthlyPro.rawValue {
                    return true
                }
                return false
            }
            
            #if DEBUG
            print("🛒 Loaded \(products.count) products:")
            for product in products {
                print("   - \(product.id): \(product.displayPrice)")
            }
            #endif
        } catch {
            #if DEBUG
            print("🛒 Failed to load products: \(error)")
            #endif
            errorMessage = "Failed to load subscription options"
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
                        // Check if auto-renew is enabled
                        let willAutoRenew = renewalInfo.willAutoRenew
                        
                        let subscriptionStatus = SubscriptionStatus(
                            plan: .pro,
                            expirationDate: transaction.expirationDate,
                            willRenew: willAutoRenew
                        )
                        self.subscriptionStatus = subscriptionStatus
                        
                        #if DEBUG
                        print("🛒 Active subscription found: \(transaction.productID)")
                        print("   Expires: \(transaction.expirationDate?.description ?? "never")")
                        print("   Will renew: \(willAutoRenew)")
                        print("   State: \(status.state)")
                        #endif
                        
                        return
                    }
                }
            } catch {
                #if DEBUG
                print("🛒 Error checking subscription status: \(error)")
                #endif
            }
        }
        
        // Fallback: Check currentEntitlements if products aren't loaded yet
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            // Check if this is one of our subscription products
            if SubscriptionProduct.allIdentifiers.contains(transaction.productID) {
                // Found an active subscription (assume will renew since we can't check here)
                let status = SubscriptionStatus(
                    plan: .pro,
                    expirationDate: transaction.expirationDate,
                    willRenew: true // Default to true, detailed check above is more accurate
                )
                subscriptionStatus = status
                
                #if DEBUG
                print("🛒 Active subscription found (fallback): \(transaction.productID)")
                print("   Expires: \(transaction.expirationDate?.description ?? "never")")
                #endif
                
                return
            }
        }
        
        // No active subscription found
        subscriptionStatus = .trial
        
        #if DEBUG
        print("🛒 No active subscription - using Trial plan")
        #endif
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
        
        #if DEBUG
        print("🛒 Attempting purchase: \(product.id)")
        #endif
        
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
                
                #if DEBUG
                print("🛒 Purchase successful: \(product.id)")
                #endif
                
                return true
                
            case .userCancelled:
                #if DEBUG
                print("🛒 Purchase cancelled by user")
                #endif
                throw SubscriptionError.purchaseCancelled
                
            case .pending:
                #if DEBUG
                print("🛒 Purchase pending (e.g., Ask to Buy)")
                #endif
                return false
                
            @unknown default:
                return false
            }
        } catch let error as SubscriptionError {
            throw error
        } catch {
            #if DEBUG
            print("🛒 Purchase error: \(error)")
            #endif
            throw SubscriptionError.unknown(error)
        }
    }
    
    // MARK: - Restore Purchases
    
    /// Restore previous purchases
    func restorePurchases() async throws {
        #if DEBUG
        print("🛒 Restoring purchases...")
        #endif
        
        // Sync with App Store
        try await AppStore.sync()
        
        // Re-check subscription status
        await checkSubscriptionStatus()
        
        #if DEBUG
        print("🛒 Restore complete. Current plan: \(currentPlan.displayName)")
        #endif
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
            #if DEBUG
            print("🛒 Failed to open manage subscriptions: \(error)")
            #endif
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
                
                // Finish the transaction
                await transaction.finish()
                
                // Update subscription status on main actor
                await self?.checkSubscriptionStatus()
                
                #if DEBUG
                print("🛒 Transaction update: \(transaction.productID)")
                #endif
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
