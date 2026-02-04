//
//  SubscriptionModels.swift
//  Guidepost
//
//  Created by John Gambrell on 2/3/26.
//

import Foundation

// MARK: - Subscription Plan

/// Represents the user's current subscription tier
enum SubscriptionPlan: String, CaseIterable, Sendable {
    case trial = "trial"
    case pro = "pro"
    
    var displayName: String {
        switch self {
        case .trial: return "Trial"
        case .pro: return "Pro"
        }
    }
    
    /// Upload limit for the plan. `nil` means unlimited.
    var uploadLimit: Int? {
        switch self {
        case .trial: return 10
        case .pro: return nil
        }
    }
    
    /// Whether uploads are unlimited on this plan
    var hasUnlimitedUploads: Bool {
        uploadLimit == nil
    }
}

// MARK: - Subscription Product Identifiers

/// App Store product identifiers for subscription products
enum SubscriptionProduct: String, CaseIterable, Sendable {
    case monthlyPro = "com.gambrell.guidepost2026.pro.monthly"
    case yearlyPro = "com.gambrell.guidepost2026.pro.yearly"
    
    /// All product identifiers as a Set for StoreKit queries
    static var allIdentifiers: Set<String> {
        Set(allCases.map(\.rawValue))
    }
    
    var displayName: String {
        switch self {
        case .monthlyPro: return "Monthly"
        case .yearlyPro: return "Yearly"
        }
    }
    
    /// Whether this is the yearly plan (used for showing savings badge)
    var isYearly: Bool {
        self == .yearlyPro
    }
}

// MARK: - Subscription Status

/// Represents the current subscription status with expiration info
struct SubscriptionStatus: Sendable {
    let plan: SubscriptionPlan
    let expirationDate: Date?
    let willRenew: Bool
    
    /// Default trial status for non-subscribed users
    static let trial = SubscriptionStatus(plan: .trial, expirationDate: nil, willRenew: false)
    
    /// Whether the subscription is currently active (not expired)
    var isActive: Bool {
        guard plan == .pro, let expiration = expirationDate else {
            return plan == .trial
        }
        return Date() < expiration
    }
    
    /// Formatted expiration date for display
    var formattedExpirationDate: String? {
        guard let date = expirationDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Purchase Error

/// Errors that can occur during StoreKit operations
enum SubscriptionError: Error, LocalizedError {
    case productNotFound
    case purchaseFailed(String)
    case purchaseCancelled
    case verificationFailed
    case networkError
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Subscription product not found"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .purchaseCancelled:
            return "Purchase was cancelled"
        case .verificationFailed:
            return "Could not verify purchase"
        case .networkError:
            return "Network error. Please check your connection."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
