//
//  ContentView.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(ImageGridViewModel.self) private var imageGridViewModel
    @Environment(AppearanceManager.self) private var appearanceManager
    @Environment(StoreKitService.self) private var storeKitService
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                HomeView()
            } else {
                AuthFlowView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .preferredColorScheme(appearanceManager.colorScheme)
        .task {
            // Check subscription status on app launch for non-guest authenticated users
            if authViewModel.isAuthenticated && !authViewModel.isGuest {
                await storeKitService.checkSubscriptionStatus()
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { wasAuthenticated, isAuthenticated in
            if wasAuthenticated && !isAuthenticated {
                // User signed out - clear all cached data to prevent data leaking between users
                imageGridViewModel.clearAllData()
                storeKitService.resetSubscriptionStatus()
            } else if !wasAuthenticated && isAuthenticated && !authViewModel.isGuest {
                // Non-guest user signed in - re-check subscription status
                // Guests always start on Trial (they must create account before subscribing)
                Task {
                    await storeKitService.checkSubscriptionStatus()
                }
            }
        }
        .onChange(of: authViewModel.isGuest) { wasGuest, isGuest in
            // When guest upgrades to full account, check subscription status
            if wasGuest && !isGuest && authViewModel.isAuthenticated {
                Task {
                    await storeKitService.checkSubscriptionStatus()
                }
            }
        }
    }
}

// MARK: - Auth Flow View

struct AuthFlowView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    
    var body: some View {
        switch authViewModel.authFlowState {
        case .signIn:
            SignInView()
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
            
        case .signUp:
            SignUpView()
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            
        case .forgotPassword:
            ForgotPasswordView()
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            
        case .confirmForgotPassword(let email):
            ConfirmForgotPasswordView(email: email)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
        }
    }
}

#Preview("Authenticated") {
    let authVM = AuthViewModel()
    // Simulate authenticated state for preview
    ContentView()
        .environment(authVM)
        .environment(ImageGridViewModel())
        .environment(AppearanceManager())
        .environment(StoreKitService())
        .onAppear {
            // Note: In real app, this would be set by successful login
        }
}

#Preview("Not Authenticated") {
    ContentView()
        .environment(AuthViewModel())
        .environment(ImageGridViewModel())
        .environment(AppearanceManager())
        .environment(StoreKitService())
}
