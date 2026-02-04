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
    @Environment(AuthViewModel.self) private var authViewModel
    
    @State private var selectedProduct: Product?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var showUpgradeAccountSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Guest account warning - must create account first
                        if authViewModel.isGuest {
                            guestAccountWarning
                        }
                        
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
                        
                        // Purchase button (or create account button for guests)
                        if selectedProduct != nil {
                            if authViewModel.isGuest {
                                createAccountButton
                            } else {
                                purchaseButton
                            }
                        }
                        
                        // Restore purchases (only for non-guests)
                        if !authViewModel.isGuest {
                            restoreButton
                        }
                        
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
            .sheet(isPresented: $showUpgradeAccountSheet) {
                SubscriptionUpgradeAccountView(
                    selectedProduct: selectedProduct,
                    onAccountCreated: {
                        // After account is created, proceed with purchase
                        Task {
                            await purchase()
                        }
                    }
                )
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
    
    // MARK: - Guest Account Warning
    
    private var guestAccountWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Account Required")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.theme.textPrimary)
                
                Text("Create an account to subscribe. This ensures you can always access your subscription.")
                    .font(.caption)
                    .foregroundStyle(Color.theme.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Create Account Button (for guests)
    
    private var createAccountButton: some View {
        Button {
            showUpgradeAccountSheet = true
        } label: {
            HStack {
                Image(systemName: "person.badge.plus")
                Text("Create Account & Subscribe")
                    .fontWeight(.semibold)
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
                Link("Privacy Policy", destination: URL(string: "https://www.freeprivacypolicy.com/live/d758cdad-ddfb-4ba7-9f37-aab1c489e1a0")!)
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

// MARK: - Subscription Upgrade Account View

/// A view that prompts guest users to create an account before subscribing
struct SubscriptionUpgradeAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    
    let selectedProduct: Product?
    let onAccountCreated: () -> Void
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isUpgrading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                        }
                        
                        Text("Create Your Account")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let product = selectedProduct {
                            Text("Create an account to subscribe to \(product.displayName) for \(product.displayPrice)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Create an account to manage your subscription")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Error message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                    
                    // Form fields
                    VStack(spacing: 16) {
                        // Name fields
                        HStack(spacing: 12) {
                            AuthTextField(
                                icon: "person.fill",
                                placeholder: "First Name",
                                text: $firstName
                            )
                            
                            AuthTextField(
                                icon: "person.fill",
                                placeholder: "Last Name",
                                text: $lastName
                            )
                        }
                        
                        AuthTextField(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $email,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress
                        )
                        
                        AuthSecureField(
                            icon: "lock.fill",
                            placeholder: "Password",
                            text: $password
                        )
                        
                        // Password requirements hint
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Password must contain:")
                                .font(.caption)
                                .foregroundStyle(Color.theme.textSecondary)
                            HStack(spacing: 16) {
                                PasswordRequirement(text: "8+ chars", met: password.count >= 8)
                                PasswordRequirement(text: "Uppercase", met: password.contains(where: { $0.isUppercase }))
                                PasswordRequirement(text: "Number", met: password.contains(where: { $0.isNumber }))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        
                        AuthSecureField(
                            icon: "lock.fill",
                            placeholder: "Confirm Password",
                            text: $confirmPassword
                        )
                        
                        // Password match indicator
                        if !confirmPassword.isEmpty {
                            HStack {
                                Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                Text(password == confirmPassword ? "Passwords match" : "Passwords don't match")
                            }
                            .font(.caption)
                            .foregroundStyle(password == confirmPassword ? .green : .red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Create account and subscribe button
                    Button(action: upgradeAndSubscribe) {
                        HStack {
                            if isUpgrading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Create Account & Continue")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isUpgrading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Text("After creating your account, you'll be prompted to complete your subscription purchase.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func upgradeAndSubscribe() {
        // Validation
        guard !firstName.isEmpty else {
            errorMessage = "Please enter your first name"
            return
        }
        guard !lastName.isEmpty else {
            errorMessage = "Please enter your last name"
            return
        }
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter a password"
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        guard password.contains(where: { $0.isUppercase }) else {
            errorMessage = "Password must contain an uppercase letter"
            return
        }
        guard password.contains(where: { $0.isNumber }) else {
            errorMessage = "Password must contain a number"
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        isUpgrading = true
        errorMessage = nil
        
        Task {
            do {
                try await authViewModel.upgradeGuestAccount(
                    email: email,
                    password: password,
                    givenName: firstName,
                    familyName: lastName
                )
                await MainActor.run {
                    isUpgrading = false
                    dismiss()
                    // Trigger the purchase flow after account creation
                    onAccountCreated()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isUpgrading = false
                }
            }
        }
    }
}

#Preview {
    SubscriptionView()
        .environment(StoreKitService())
        .environment(AuthViewModel())
}
