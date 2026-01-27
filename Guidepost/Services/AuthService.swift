//
//  AuthService.swift
//  Guidepost
//
//  Created by John Gambrell on 1/18/26.
//

import Foundation
import Security

// MARK: - Keychain Helper

private enum KeychainKey: String {
    case accessToken = "com.guidepost.accessToken"
    case idToken = "com.guidepost.idToken"
    case refreshToken = "com.guidepost.refreshToken"
    case tokenExpiration = "com.guidepost.tokenExpiration"
}

private struct KeychainHelper {
    // Shared access group for keychain items - allows sharing between main app and share extension
    private static let accessGroup = "group.com.gambrell.guidepost2026.shared"
    
    static func save(_ data: Data, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    static func save(_ string: String, forKey key: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return save(data, forKey: key)
    }
    
    static func load(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    
    static func loadString(forKey key: String) -> String? {
        guard let data = load(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Migration Helper
    
    /// Load data from old keychain (without access group) for migration
    static func loadFromOldKeychain(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    
    /// Delete data from old keychain (without access group) after migration
    static func deleteFromOldKeychain(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - Auth Service

class AuthService {
    static let shared = AuthService()
    
    private let baseURL = "https://0p19v2252j.execute-api.us-east-1.amazonaws.com/prod"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        // Migrate tokens from old keychain to shared keychain if needed
        migrateTokensIfNeeded()
    }
    
    // MARK: - Token Migration
    
    /// Migrate tokens from old keychain (pre-share extension) to shared keychain
    /// This allows existing users to continue using the app after the update
    private func migrateTokensIfNeeded() {
        // Check if we already have tokens in the shared keychain
        if currentIdToken != nil {
            // Already migrated or fresh install
            return
        }
        
        // Try to load tokens from old keychain
        let keysToMigrate = [
            KeychainKey.accessToken.rawValue,
            KeychainKey.idToken.rawValue,
            KeychainKey.refreshToken.rawValue,
            KeychainKey.tokenExpiration.rawValue
        ]
        
        var migratedAny = false
        
        for key in keysToMigrate {
            if let oldData = KeychainHelper.loadFromOldKeychain(forKey: key) {
                // Save to new shared keychain
                if KeychainHelper.save(oldData, forKey: key) {
                    // Delete from old keychain
                    _ = KeychainHelper.deleteFromOldKeychain(forKey: key)
                    migratedAny = true
                    #if DEBUG
                    print("🔑 Migrated keychain item: \(key)")
                    #endif
                }
            }
        }
        
        if migratedAny {
            #if DEBUG
            print("🔑 Token migration completed successfully")
            #endif
        }
    }
    
    // MARK: - Token Management
    
    var currentAccessToken: String? {
        KeychainHelper.loadString(forKey: KeychainKey.accessToken.rawValue)
    }
    
    var currentIdToken: String? {
        KeychainHelper.loadString(forKey: KeychainKey.idToken.rawValue)
    }
    
    var currentRefreshToken: String? {
        KeychainHelper.loadString(forKey: KeychainKey.refreshToken.rawValue)
    }
    
    var isAuthenticated: Bool {
        currentIdToken != nil
    }
    
    var isTokenExpired: Bool {
        guard let expirationString = KeychainHelper.loadString(forKey: KeychainKey.tokenExpiration.rawValue),
              let expirationInterval = Double(expirationString) else {
            return true
        }
        let expirationDate = Date(timeIntervalSince1970: expirationInterval)
        // Consider expired if less than 5 minutes remaining
        return Date().addingTimeInterval(300) > expirationDate
    }
    
    private func saveTokens(_ tokens: AuthTokens) {
        _ = KeychainHelper.save(tokens.accessToken, forKey: KeychainKey.accessToken.rawValue)
        _ = KeychainHelper.save(tokens.idToken, forKey: KeychainKey.idToken.rawValue)
        if let refreshToken = tokens.refreshToken {
            _ = KeychainHelper.save(refreshToken, forKey: KeychainKey.refreshToken.rawValue)
        }
        let expiration = Date().addingTimeInterval(TimeInterval(tokens.expiresIn)).timeIntervalSince1970
        _ = KeychainHelper.save(String(expiration), forKey: KeychainKey.tokenExpiration.rawValue)
    }
    
    func clearTokens() {
        _ = KeychainHelper.delete(forKey: KeychainKey.accessToken.rawValue)
        _ = KeychainHelper.delete(forKey: KeychainKey.idToken.rawValue)
        _ = KeychainHelper.delete(forKey: KeychainKey.refreshToken.rawValue)
        _ = KeychainHelper.delete(forKey: KeychainKey.tokenExpiration.rawValue)
    }
    
    // MARK: - API Endpoints
    
    /// POST /api/auth/signup
    func signUp(email: String, password: String, givenName: String, familyName: String) async throws -> SignUpResponseData {
        let request = SignUpRequest(email: email, password: password, givenName: givenName, familyName: familyName)
        let response: AuthAPIResponse<SignUpResponseData> = try await post(endpoint: "/api/auth/signup", body: request)
        
        guard response.success, let data = response.data else {
            throw mapError(response.error, statusCode: nil)
        }
        
        return data
    }
    
    /// POST /api/auth/signin
    func signIn(email: String, password: String) async throws -> AuthTokens {
        let request = SignInRequest(email: email, password: password)
        let response: AuthAPIResponse<AuthTokens> = try await post(endpoint: "/api/auth/signin", body: request)
        
        guard response.success, let tokens = response.data else {
            throw mapError(response.error, statusCode: nil)
        }
        
        saveTokens(tokens)
        return tokens
    }
    
    /// POST /api/auth/refresh
    func refreshAccessToken() async throws -> AuthTokens {
        guard let refreshToken = currentRefreshToken else {
            throw AuthError.notAuthenticated
        }
        
        let request = RefreshTokenRequest(refreshToken: refreshToken)
        let response: AuthAPIResponse<AuthTokens> = try await post(endpoint: "/api/auth/refresh", body: request)
        
        guard response.success, let tokens = response.data else {
            // If refresh fails, clear tokens and require re-authentication
            clearTokens()
            throw AuthError.tokenExpired
        }
        
        saveTokens(tokens)
        return tokens
    }
    
    /// POST /api/auth/forgot-password
    func forgotPassword(email: String) async throws {
        let request = ForgotPasswordRequest(email: email)
        let response: AuthAPIResponse<ForgotPasswordResponseData> = try await post(endpoint: "/api/auth/forgot-password", body: request)
        
        guard response.success else {
            throw mapError(response.error, statusCode: nil)
        }
    }
    
    /// POST /api/auth/confirm-forgot-password
    func confirmForgotPassword(email: String, confirmationCode: String, newPassword: String) async throws {
        let request = ConfirmForgotPasswordRequest(email: email, confirmationCode: confirmationCode, newPassword: newPassword)
        let response: AuthAPIResponse<ConfirmResponseData> = try await post(endpoint: "/api/auth/confirm-forgot-password", body: request)
        
        guard response.success else {
            throw mapError(response.error, statusCode: nil)
        }
    }
    
    /// GET /api/auth/me
    func getMe() async throws -> User {
        let response: AuthAPIResponse<User> = try await get(endpoint: "/api/auth/me", authenticated: true)
        
        guard response.success, let user = response.data else {
            throw mapError(response.error, statusCode: nil)
        }
        
        return user
    }
    
    /// Ensure we have a valid ID token, refreshing if needed
    /// Note: API Gateway Cognito authorizers require ID token, not access token
    func ensureValidToken() async throws -> String {
        if isTokenExpired {
            _ = try await refreshAccessToken()
        }
        
        guard let token = currentIdToken else {
            throw AuthError.notAuthenticated
        }
        
        return token
    }
    
    // MARK: - HTTP Helpers
    
    private func post<T: Codable, R: Codable>(endpoint: String, body: T) async throws -> R {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        return try await performRequest(request)
    }
    
    private func get<R: Codable>(endpoint: String, authenticated: Bool) async throws -> R {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if authenticated {
            // API Gateway Cognito authorizers require ID token, not access token
            guard let token = currentIdToken else {
                throw AuthError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return try await performRequest(request)
    }
    
    private func performRequest<R: Codable>(_ request: URLRequest) async throws -> R {
        do {
            // Debug: Print request details
            #if DEBUG
            print("🌐 Request URL: \(request.url?.absoluteString ?? "nil")")
            print("🌐 Request Method: \(request.httpMethod ?? "nil")")
            print("🌐 Request Headers: \(request.allHTTPHeaderFields ?? [:])")
            if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
                print("🌐 Request Body: \(bodyString)")
            }
            #endif
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            // Debug: Print response details
            #if DEBUG
            print("🌐 Response Status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("🌐 Response Body: \(responseString)")
            }
            #endif
            
            // Try to decode error response for non-success status codes
            if !(200...299).contains(httpResponse.statusCode) {
                if let errorResponse = try? JSONDecoder().decode(AuthAPIResponse<EmptyResponse>.self, from: data) {
                    throw mapError(errorResponse.error, statusCode: httpResponse.statusCode)
                }
                throw AuthError.httpError(statusCode: httpResponse.statusCode, message: nil)
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(R.self, from: data)
        } catch let error as AuthError {
            throw error
        } catch let error as DecodingError {
            #if DEBUG
            print("🌐 Decoding Error: \(error)")
            #endif
            throw AuthError.decodingError(error)
        } catch {
            #if DEBUG
            print("🌐 Network Error: \(error)")
            #endif
            throw AuthError.networkError(error)
        }
    }
    
    private func mapError(_ errorMessage: String?, statusCode: Int?) -> AuthError {
        guard let message = errorMessage?.lowercased() else {
            if let code = statusCode {
                return .httpError(statusCode: code, message: nil)
            }
            return .unknownError("An unknown error occurred")
        }
        
        if message.contains("already exists") {
            return .userAlreadyExists
        } else if message.contains("invalid email or password") || message.contains("invalid credentials") {
            return .invalidCredentials
        }  else if message.contains("invalid confirmation code") || message.contains("expired") {
            return .invalidConfirmationCode
        } else if message.contains("password") && message.contains("requirement") {
            return .passwordRequirementsNotMet
        }
        
        return .unknownError(errorMessage ?? "An unknown error occurred")
    }
}

// Empty response for error decoding
private struct EmptyResponse: Codable {}


