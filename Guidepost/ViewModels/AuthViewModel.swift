//
//  AuthViewModel.swift
//  Guidepost
//
//  Created by John Gambrell on 1/18/26.
//

import Foundation
import Observation

// MARK: - Auth Flow State

enum AuthFlowState: Equatable {
    case signIn
    case signUp
    case forgotPassword
    case confirmForgotPassword(email: String)
}

// MARK: - Auth View Model

@Observable
class AuthViewModel {
    // MARK: - Published State
    
    var isAuthenticated: Bool = false
    var currentUser: User?
    var isLoading: Bool = false
    var errorMessage: String?
    var successMessage: String?
    
    // Auth flow navigation
    var authFlowState: AuthFlowState = .signIn
    
    // Form fields
    var email: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    var givenName: String = ""
    var familyName: String = ""
    var confirmationCode: String = ""
    var newPassword: String = ""
    
    // MARK: - Private
    
    private let authService = AuthService.shared
    
    // MARK: - Initialization
    
    init() {
        // Check if user is already authenticated
        checkAuthStatus()
    }
    
    // MARK: - Auth Status
    
    func checkAuthStatus() {
        isAuthenticated = authService.isAuthenticated
        
        if isAuthenticated {
            // Fetch user profile in background
            Task {
                await fetchUserProfile()
            }
        }
    }
    
    func fetchUserProfile() async {
        do {
            let user = try await authService.getMe()
            await MainActor.run {
                self.currentUser = user
            }
        } catch {
            // If we can't fetch profile, token might be invalid
            await MainActor.run {
                if case AuthError.notAuthenticated = error {
                    self.signOut()
                } else if case AuthError.tokenExpired = error {
                    self.signOut()
                }
            }
        }
    }
    
    // MARK: - Sign In
    
    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password"
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            _ = try await authService.signIn(email: email, password: password)
            let user = try await authService.getMe()
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.clearFormFields()
                self.isLoading = false
            }
        } catch let error as AuthError {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Sign Up
    
    func signUp() async {
        guard validateSignUpFields() else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            _ = try await authService.signUp(
                email: email,
                password: password,
                givenName: givenName,
                familyName: familyName
            )
            
            await MainActor.run {
                self.successMessage = "Account created successfully! You can now sign in."
                self.authFlowState = .signIn
                self.password = ""
                self.confirmPassword = ""
                self.isLoading = false
            }
        } catch let error as AuthError {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func validateSignUpFields() -> Bool {
        if email.isEmpty {
            errorMessage = "Please enter your email"
            return false
        }
        if password.isEmpty {
            errorMessage = "Please enter a password"
            return false
        }
        if password.count < 8 {
            errorMessage = "Password must be at least 8 characters"
            return false
        }
        if password != confirmPassword {
            errorMessage = "Passwords do not match"
            return false
        }
        if givenName.isEmpty {
            errorMessage = "Please enter your first name"
            return false
        }
        if familyName.isEmpty {
            errorMessage = "Please enter your last name"
            return false
        }
        return true
    }
    
    // MARK: - Forgot Password
    
    func forgotPassword() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await authService.forgotPassword(email: email)
            
            await MainActor.run {
                self.successMessage = "Password reset code sent to your email."
                self.authFlowState = .confirmForgotPassword(email: self.email)
                self.isLoading = false
            }
        } catch let error as AuthError {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Confirm Forgot Password
    
    func confirmForgotPassword() async {
        guard !confirmationCode.isEmpty else {
            errorMessage = "Please enter the confirmation code"
            return
        }
        guard !newPassword.isEmpty else {
            errorMessage = "Please enter a new password"
            return
        }
        guard newPassword.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        
        guard case .confirmForgotPassword(let resetEmail) = authFlowState else {
            errorMessage = "Invalid state"
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await authService.confirmForgotPassword(
                email: resetEmail,
                confirmationCode: confirmationCode,
                newPassword: newPassword
            )
            
            await MainActor.run {
                self.successMessage = "Password reset successfully! You can now sign in."
                self.authFlowState = .signIn
                self.confirmationCode = ""
                self.newPassword = ""
                self.isLoading = false
            }
        } catch let error as AuthError {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        authService.clearTokens()
        isAuthenticated = false
        currentUser = nil
        clearFormFields()
        authFlowState = .signIn
    }
    
    // MARK: - Navigation Helpers
    
    func navigateToSignUp() {
        clearFormFields()
        errorMessage = nil
        successMessage = nil
        authFlowState = .signUp
    }
    
    func navigateToSignIn() {
        clearFormFields()
        errorMessage = nil
        successMessage = nil
        authFlowState = .signIn
    }
    
    func navigateToForgotPassword() {
        errorMessage = nil
        successMessage = nil
        authFlowState = .forgotPassword
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func clearSuccess() {
        successMessage = nil
    }
    
    private func clearFormFields() {
        email = ""
        password = ""
        confirmPassword = ""
        givenName = ""
        familyName = ""
        confirmationCode = ""
        newPassword = ""
    }
}


