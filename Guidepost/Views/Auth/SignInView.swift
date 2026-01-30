//
//  SignInView.swift
//  Guidepost
//
//  Created by John Gambrell on 1/18/26.
//

import SwiftUI

struct SignInView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case email, password
    }
    
    var body: some View {
        @Bindable var authViewModel = authViewModel
        
        NavigationStack {
            ZStack {
                // Background gradient
                AdaptiveBackground()
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: 40)
                        
                        // Logo/Header
                        VStack(spacing: 12) {
                            Image("LaunchIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .shadow(color: .cyan.opacity(0.5), radius: 20)
                            
                            Text("Guidepost")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.theme.textPrimary)
                            
                            Text("Your camera's new superpower: snap it, forget it, find it instantly.")
                                .font(.subheadline)
                                .foregroundStyle(Color.theme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.bottom, 20)
                        
                        // Form
                        VStack(spacing: 20) {
                            // Success message
                            if let successMessage = authViewModel.successMessage {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text(successMessage)
                                        .font(.callout)
                                        .foregroundStyle(.green)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
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
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            
                            // Password field
                            AuthSecureField(
                                icon: "lock.fill",
                                placeholder: "Password",
                                text: $authViewModel.password
                            )
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit {
                                Task { await authViewModel.signIn() }
                            }
                            
                            // Forgot password
                            HStack {
                                Spacer()
                                Button(action: { authViewModel.navigateToForgotPassword() }) {
                                    Text("Forgot Password?")
                                        .font(.callout)
                                        .foregroundStyle(Color.theme.accent)
                                }
                            }
                            
                            // Sign in button
                            Button(action: {
                                Task { await authViewModel.signIn() }
                            }) {
                                HStack {
                                    if authViewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Sign In")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.063, green: 0.725, blue: 0.506), // #10B981
                                            Color(red: 0.020, green: 0.588, blue: 0.412)  // #059669
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Color(red: 0.020, green: 0.588, blue: 0.412).opacity(0.4), radius: 15, x: 0, y: 8)
                            }
                            .disabled(authViewModel.isLoading)
                            .padding(.top, 8)
                            
                            // Try the App button (Guest mode)
                            Button(action: {
                                Task { await authViewModel.tryAsGuest() }
                            }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Try the App")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.theme.inputBackground)
                                .foregroundStyle(Color.theme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.theme.inputBorder, lineWidth: 1)
                                )
                            }
                            .disabled(authViewModel.isLoading)
                            
                            Text("Try with 10 free uploads, no sign-up required")
                                .font(.caption)
                                .foregroundStyle(Color.theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer()
                        
                        // Sign up link
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundStyle(Color.theme.textSecondary)
                            Button(action: { authViewModel.navigateToSignUp() }) {
                                Text("Sign Up")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.theme.accent)
                            }
                        }
                        .font(.callout)
                        .padding(.bottom, 30)
                    }
                }
            }
            .onAppear {
                authViewModel.clearError()
            }
        }
    }
}

// MARK: - Auth Text Field

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.theme.textSecondary)
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .foregroundStyle(Color.theme.textPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.theme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.theme.inputBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Auth Secure Field

struct AuthSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isSecure: Bool = true
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.theme.textSecondary)
                .frame(width: 24)
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.password)
            .foregroundStyle(Color.theme.textPrimary)
            
            Button(action: { isSecure.toggle() }) {
                Image(systemName: isSecure ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.theme.textSecondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.theme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.theme.inputBorder, lineWidth: 1)
                )
        )
    }
}

#Preview {
    SignInView()
        .environment(AuthViewModel())
}


