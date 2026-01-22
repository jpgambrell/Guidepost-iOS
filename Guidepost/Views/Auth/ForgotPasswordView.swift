//
//  ForgotPasswordView.swift
//  Guidepost
//
//  Created by John Gambrell on 1/18/26.
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    
    var body: some View {
        @Bindable var authViewModel = authViewModel
        
        ZStack {
            // Background gradient
            AdaptiveBackground()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        HStack {
                            Button(action: { authViewModel.navigateToSignIn() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Color.theme.textPrimary)
                                    .padding(12)
                                    .background(Color.theme.inputBackground)
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        Image(systemName: "key.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .orange.opacity(0.5), radius: 20)
                            .padding(.top, 20)
                        
                        Text("Forgot Password")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.theme.textPrimary)
                        
                        Text("Enter your email and we'll send you a code to reset your password")
                            .font(.subheadline)
                            .foregroundStyle(Color.theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 20)
                    
                    // Form
                    VStack(spacing: 20) {
                        // Error message
                        if let errorMessage = authViewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(errorMessage)
                                    .font(.callout)
                                    .foregroundStyle(.red)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Email field
                        AuthTextField(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $authViewModel.email,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress
                        )
                        
                        // Send code button
                        Button(action: {
                            Task { await authViewModel.forgotPassword() }
                        }) {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Send Reset Code")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .orange.opacity(0.4), radius: 15, x: 0, y: 8)
                        }
                        .disabled(authViewModel.isLoading)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Back to sign in
                    Button(action: { authViewModel.navigateToSignIn() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.left")
                            Text("Back to Sign In")
                        }
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.theme.accent)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            authViewModel.clearError()
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environment(AuthViewModel())
}


