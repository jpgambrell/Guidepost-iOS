//
//  SubscriptionView.swift
//  Guidepost
//
//  Created by John Gambrell on 2/3/26.
//

import SwiftUI
import StoreKit

// MARK: - Subscription View

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreKitService.self) private var storeKitService
    
    @State private var selectedProduct: Product?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Features comparison
                        featuresSection
                        
                        // Subscription options
                        if storeKitService.isLoadingProducts {
                            loadingSection
                        } else if storeKitService.products.isEmpty {
                            emptyProductsSection
                        } else {
                            productsSection
                        }
                        
                        // Purchase button
                        if selectedProduct != nil {
                            purchaseButton
                        }
                        
                        // Restore purchases
                        restoreButton
                        
                        // Legal links
                        legalSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success!", isPresented: $showSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("You're now a Pro subscriber! Enjoy unlimited uploads.")
            }
            .task {
                // Select yearly by default if available
                if selectedProduct == nil, let yearly = storeKitService.yearlyProduct {
                    selectedProduct = yearly
                } else if selectedProduct == nil, let monthly = storeKitService.monthlyProduct {
                    selectedProduct = monthly
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Unlock Pro Features")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.theme.textPrimary)
            
            Text("Get unlimited uploads and premium features")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(spacing: 16) {
            FeatureComparisonRow(
                feature: "Image Uploads",
                trialValue: "10 uploads",
                proValue: "Unlimited"
            )
            
            FeatureComparisonRow(
                feature: "Image Analysis",
                trialValue: "Basic",
                proValue: "Priority"
            )
            
            FeatureComparisonRow(
                feature: "Support",
                trialValue: "Community",
                proValue: "Priority"
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.theme.backgroundSecondary)
        )
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading subscription options...")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
        }
        .frame(height: 150)
    }
    
    // MARK: - Empty Products Section
    
    private var emptyProductsSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            Text("Unable to load subscription options")
                .font(.headline)
                .foregroundStyle(Color.theme.textPrimary)
            
            Text("Please check your internet connection and try again.")
                .font(.subheadline)
                .foregroundStyle(Color.theme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task {
                    await storeKitService.loadProducts()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    // MARK: - Products Section
    
    private var productsSection: some View {
        VStack(spacing: 12) {
            ForEach(storeKitService.products, id: \.id) { product in
                SubscriptionProductCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    savingsPercentage: product.yearlySavingsPercentage(comparedTo: storeKitService.monthlyProduct)
                ) {
                    selectedProduct = product
                }
            }
        }
    }
    
    // MARK: - Purchase Button
    
    private var purchaseButton: some View {
        Button {
            Task {
                await purchase()
            }
        } label: {
            HStack {
                if storeKitService.isPurchasing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Subscribe Now")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [.cyan, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(.rect(cornerRadius: 12))
        }
        .disabled(storeKitService.isPurchasing || selectedProduct == nil)
    }
    
    // MARK: - Restore Button
    
    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task {
                await restorePurchases()
            }
        }
        .font(.subheadline)
        .foregroundStyle(Color.theme.accent)
    }
    
    // MARK: - Legal Section
    
    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("Subscriptions will be charged to your Apple ID account at confirmation of purchase. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundStyle(Color.theme.textSecondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Link("Terms of Service", destination: URL(string: "https://guidepost.app/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://guidepost.app/privacy")!)
            }
            .font(.caption)
            .foregroundStyle(Color.theme.accent)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func purchase() async {
        guard let product = selectedProduct else { return }
        
        do {
            let success = try await storeKitService.purchase(product)
            if success {
                showSuccess = true
            }
        } catch SubscriptionError.purchaseCancelled {
            // User cancelled, don't show error
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func restorePurchases() async {
        do {
            try await storeKitService.restorePurchases()
            if storeKitService.isSubscribed {
                showSuccess = true
            }
        } catch {
            errorMessage = "Failed to restore purchases. Please try again."
            showError = true
        }
    }
}

// MARK: - Feature Comparison Row

private struct FeatureComparisonRow: View {
    let feature: String
    let trialValue: String
    let proValue: String
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .foregroundStyle(Color.theme.textPrimary)
            
            Spacer()
            
            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("Trial")
                        .font(.caption2)
                        .foregroundStyle(Color.theme.textSecondary)
                    Text(trialValue)
                        .font(.caption)
                        .foregroundStyle(Color.theme.textSecondary)
                }
                .frame(width: 70)
                
                VStack(spacing: 2) {
                    Text("Pro")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.theme.accent)
                    Text(proValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.theme.accent)
                }
                .frame(width: 70)
            }
        }
    }
}

// MARK: - Subscription Product Card

private struct SubscriptionProductCard: View {
    let product: Product
    let isSelected: Bool
    let savingsPercentage: Int?
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundStyle(Color.theme.textPrimary)
                        
                        if let savings = savingsPercentage, savings > 0 {
                            Text("Save \(savings)%")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.green)
                                )
                        }
                    }
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(Color.theme.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.theme.textPrimary)
                    
                    if let subscription = product.subscription {
                        Text(subscription.subscriptionPeriod.displayUnit)
                            .font(.caption)
                            .foregroundStyle(Color.theme.textSecondary)
                    }
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.theme.accent : Color.theme.textSecondary)
                    .padding(.leading, 8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.theme.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.theme.accent : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subscription Period Extension

extension Product.SubscriptionPeriod {
    var displayUnit: String {
        switch unit {
        case .day:
            return value == 1 ? "per day" : "per \(value) days"
        case .week:
            return value == 1 ? "per week" : "per \(value) weeks"
        case .month:
            return value == 1 ? "per month" : "per \(value) months"
        case .year:
            return value == 1 ? "per year" : "per \(value) years"
        @unknown default:
            return ""
        }
    }
}

#Preview {
    SubscriptionView()
        .environment(StoreKitService())
}
