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
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.1, blue: 0.25),
                        Color(red: 0.05, green: 0.1, blue: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: 40)
                        
                        // Logo/Header
                        VStack(spacing: 12) {
                            Image(systemName: "photo.stack.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .cyan.opacity(0.5), radius: 20)
                            
                            Text("Guidepost")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("AI-Powered Image Analysis")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
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
                                        .foregroundStyle(.cyan)
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
                                        colors: [.cyan, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: .cyan.opacity(0.4), radius: 15, x: 0, y: 8)
                            }
                            .disabled(authViewModel.isLoading)
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer()
                        
                        // Sign up link
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundStyle(.white.opacity(0.7))
                            Button(action: { authViewModel.navigateToSignUp() }) {
                                Text("Sign Up")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.cyan)
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
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
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
                .foregroundStyle(.white.opacity(0.6))
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
            .foregroundStyle(.white)
            
            Button(action: { isSecure.toggle() }) {
                Image(systemName: isSecure ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

#Preview {
    SignInView()
        .environment(AuthViewModel())
}


