//
//  ContentView.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(AppearanceManager.self) private var appearanceManager
    
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
        .onAppear {
            // Note: In real app, this would be set by successful login
        }
}

#Preview("Not Authenticated") {
    ContentView()
        .environment(AuthViewModel())
        .environment(ImageGridViewModel())
}
