//
//  SignUpView.swift
//  Guidepost
//
//  Created by John Gambrell on 1/18/26.
//

import SwiftUI

struct SignUpView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case firstName, lastName, email, password, confirmPassword
    }
    
    var body: some View {
        @Bindable var authViewModel = authViewModel
        
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
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        HStack {
                            Button(action: { authViewModel.navigateToSignIn() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .background(.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        Text("Create Account")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Sign up to get started")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // Form
                    VStack(spacing: 18) {
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
                        
                        // Name fields
                        HStack(spacing: 12) {
                            AuthTextField(
                                icon: "person.fill",
                                placeholder: "First Name",
                                text: $authViewModel.givenName,
                                textContentType: .givenName
                            )
                            .focused($focusedField, equals: .firstName)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .lastName }
                            
                            AuthTextField(
                                icon: "person.fill",
                                placeholder: "Last Name",
                                text: $authViewModel.familyName,
                                textContentType: .familyName
                            )
                            .focused($focusedField, equals: .lastName)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .email }
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
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirmPassword }
                        
                        // Password requirements hint
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Password must contain:")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            HStack(spacing: 16) {
                                PasswordRequirement(text: "8+ chars", met: authViewModel.password.count >= 8)
                                PasswordRequirement(text: "Uppercase", met: authViewModel.password.contains(where: { $0.isUppercase }))
                                PasswordRequirement(text: "Number", met: authViewModel.password.contains(where: { $0.isNumber }))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        
                        // Confirm password field
                        AuthSecureField(
                            icon: "lock.fill",
                            placeholder: "Confirm Password",
                            text: $authViewModel.confirmPassword
                        )
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.go)
                        .onSubmit {
                            Task { await authViewModel.signUp() }
                        }
                        
                        // Password match indicator
                        if !authViewModel.confirmPassword.isEmpty {
                            HStack {
                                Image(systemName: authViewModel.password == authViewModel.confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                Text(authViewModel.password == authViewModel.confirmPassword ? "Passwords match" : "Passwords don't match")
                            }
                            .font(.caption)
                            .foregroundStyle(authViewModel.password == authViewModel.confirmPassword ? .green : .red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                        }
                        
                        // Sign up button
                        Button(action: {
                            Task { await authViewModel.signUp() }
                        }) {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Create Account")
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
                    
                    // Sign in link
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(.white.opacity(0.7))
                        Button(action: { authViewModel.navigateToSignIn() }) {
                            Text("Sign In")
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

// MARK: - Password Requirement Indicator

struct PasswordRequirement: View {
    let text: String
    let met: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(met ? .green : .white.opacity(0.4))
    }
}

#Preview {
    SignUpView()
        .environment(AuthViewModel())
}


