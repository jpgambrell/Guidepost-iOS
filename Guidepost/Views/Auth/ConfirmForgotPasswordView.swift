//
//  ConfirmForgotPasswordView.swift
//  Guidepost
//
//  Created by John Gambrell on 1/18/26.
//

import SwiftUI

struct ConfirmForgotPasswordView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    let email: String
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case code, newPassword
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
                VStack(spacing: 32) {
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
                        
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .green.opacity(0.5), radius: 20)
                            .padding(.top, 20)
                        
                        Text("Reset Password")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Enter the code sent to")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Text(email)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.cyan)
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
                        
                        // Confirmation code field
                        AuthTextField(
                            icon: "number",
                            placeholder: "Confirmation Code",
                            text: $authViewModel.confirmationCode,
                            keyboardType: .numberPad,
                            textContentType: .oneTimeCode
                        )
                        .focused($focusedField, equals: .code)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .newPassword }
                        
                        // New password field
                        AuthSecureField(
                            icon: "lock.fill",
                            placeholder: "New Password",
                            text: $authViewModel.newPassword
                        )
                        .focused($focusedField, equals: .newPassword)
                        .submitLabel(.go)
                        .onSubmit {
                            Task { await authViewModel.confirmForgotPassword() }
                        }
                        
                        // Password requirements hint
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Password must contain:")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            HStack(spacing: 16) {
                                PasswordRequirement(text: "8+ chars", met: authViewModel.newPassword.count >= 8)
                                PasswordRequirement(text: "Uppercase", met: authViewModel.newPassword.contains(where: { $0.isUppercase }))
                                PasswordRequirement(text: "Number", met: authViewModel.newPassword.contains(where: { $0.isNumber }))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        
                        // Reset password button
                        Button(action: {
                            Task { await authViewModel.confirmForgotPassword() }
                        }) {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Reset Password")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .green.opacity(0.4), radius: 15, x: 0, y: 8)
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
                        .foregroundStyle(.cyan)
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
    ConfirmForgotPasswordView(email: "test@example.com")
        .environment(AuthViewModel())
}


