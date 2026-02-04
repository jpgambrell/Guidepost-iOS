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
    
    // Guest account state
    var isGuest: Bool = false
    
    // MARK: - Trial Upload Tracking
    // Applies to all users on Trial plan (guests and registered users without subscription)
    
    private let guestUploadCountKey = "com.guidepost.guestUploadCount"
    private let userUploadCountKeyPrefix = "com.guidepost.uploadCount."
    
    /// Maximum uploads allowed on the Trial plan
    let maxTrialUploads = 10
    
    /// Current upload count for trial users
    /// Uses guest key for guests, user-specific key for registered users
    var trialUploadCount: Int {
        get {
            let key = uploadCountKey
            return UserDefaults.standard.integer(forKey: key)
        }
        set {
            let key = uploadCountKey
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
    
    /// The appropriate UserDefaults key for tracking uploads based on user type
    private var uploadCountKey: String {
        if isGuest {
            return guestUploadCountKey
        } else if let userId = currentUser?.userId {
            return "\(userUploadCountKeyPrefix)\(userId)"
        }
        // Fallback to guest key if no user ID available
        return guestUploadCountKey
    }
    
    /// Remaining uploads available on the Trial plan
    var remainingTrialUploads: Int {
        max(0, maxTrialUploads - trialUploadCount)
    }
    
    // Legacy properties for backwards compatibility
    var guestUploadCount: Int {
        get { trialUploadCount }
        set { trialUploadCount = newValue }
    }
    
    var canGuestUpload: Bool {
        !isGuest || trialUploadCount < maxTrialUploads
    }
    
    var remainingGuestUploads: Int {
        remainingTrialUploads
    }
    
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
        isGuest = authService.isGuestAccount
        
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
            
            // Sign-in succeeded - user is authenticated
            await MainActor.run {
                self.isAuthenticated = true
                self.clearFormFields()
                self.isLoading = false
            }
            
            // Try to fetch user profile (non-blocking - if it fails, user is still authenticated)
            do {
                let user = try await authService.getMe()
                await MainActor.run {
                    self.currentUser = user
                }
            } catch {
                #if DEBUG
                print("⚠️ Failed to fetch user profile: \(error.localizedDescription)")
                #endif
                // User is still authenticated, just without profile info
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
        // Reset trial upload count for guests before clearing flags
        // Registered users keep their count persisted across sessions
        let wasGuest = isGuest
        
        authService.clearTokens()
        authService.clearGuestFlags()
        isAuthenticated = false
        isGuest = false
        currentUser = nil
        
        if wasGuest {
            // Clear the guest upload count key
            UserDefaults.standard.removeObject(forKey: guestUploadCountKey)
        }
        
        clearFormFields()
        authFlowState = .signIn
    }
    
    // MARK: - Try as Guest
    
    func tryAsGuest() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            _ = try await authService.createGuestAccount()
            
            await MainActor.run {
                self.isAuthenticated = true
                self.isGuest = true
                // Reset trial upload count for new guest session
                UserDefaults.standard.removeObject(forKey: self.guestUploadCountKey)
                self.isLoading = false
            }
            
            // Try to fetch user profile (non-blocking)
            do {
                let user = try await authService.getMe()
                await MainActor.run {
                    self.currentUser = user
                }
            } catch {
                #if DEBUG
                print("⚠️ Failed to fetch guest user profile: \(error.localizedDescription)")
                #endif
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
    
    // MARK: - Delete Account
    
    func deleteAccount() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            try await authService.deleteAccount()
            
            await MainActor.run {
                // Clear upload count for deleted account
                UserDefaults.standard.removeObject(forKey: self.guestUploadCountKey)
                if let userId = self.currentUser?.userId {
                    UserDefaults.standard.removeObject(forKey: "\(self.userUploadCountKeyPrefix)\(userId)")
                }
                
                self.isAuthenticated = false
                self.isGuest = false
                self.currentUser = nil
                self.clearFormFields()
                self.authFlowState = .signIn
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
    
    // MARK: - Upgrade Guest Account
    
    func upgradeGuestAccount(email: String, password: String, givenName: String, familyName: String) async throws {
        try await authService.upgradeGuestAccount(
            email: email,
            password: password,
            givenName: givenName,
            familyName: familyName
        )
        
        // Update local state - note: trial upload count persists after upgrade
        // User keeps their usage count, it just switches to the user-specific key
        await MainActor.run {
            self.isGuest = false
        }
        
        // Fetch updated user profile
        do {
            let user = try await authService.getMe()
            await MainActor.run {
                self.currentUser = user
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to fetch user profile after upgrade: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - Trial Upload Tracking Methods
    
    /// Increment the upload count for trial users
    /// This should be called after a successful upload for users on the Trial plan
    func incrementTrialUploadCount() {
        trialUploadCount += 1
    }
    
    /// Reset the trial upload count (called on sign out or account deletion)
    func resetTrialUploadCount() {
        trialUploadCount = 0
    }
    
    // Legacy method for backwards compatibility
    func incrementGuestUploadCount() {
        if isGuest {
            incrementTrialUploadCount()
        }
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


