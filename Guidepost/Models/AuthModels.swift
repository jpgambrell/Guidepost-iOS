//
//  AuthModels.swift
//  Guidepost
//
//  Created by John Gambrell on 1/18/26.
//

import Foundation

// MARK: - User Model

enum UserRole: String, Codable {
    case user
    case admin
}

struct User: Codable, Identifiable {
    let userId: String
    let email: String
    let givenName: String
    let familyName: String
    let role: UserRole
    
    var id: String { userId }
    
    var fullName: String {
        "\(givenName) \(familyName)"
    }
}

// MARK: - Auth Tokens

struct AuthTokens: Codable {
    let accessToken: String
    let idToken: String
    let refreshToken: String?
    let expiresIn: Int
    
    var expirationDate: Date {
        Date().addingTimeInterval(TimeInterval(expiresIn))
    }
}

// MARK: - Request Models

struct SignUpRequest: Codable {
    let email: String
    let password: String
    let givenName: String
    let familyName: String
}

struct SignInRequest: Codable {
    let email: String
    let password: String
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct ForgotPasswordRequest: Codable {
    let email: String
}

struct ConfirmForgotPasswordRequest: Codable {
    let email: String
    let confirmationCode: String
    let newPassword: String
}

// MARK: - Response Models

struct AuthAPIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let data: T?
    let error: String?
}

struct SignUpResponseData: Codable {
    let userId: String
    let message: String?
}

struct ForgotPasswordResponseData: Codable {
    let message: String?
}

struct ConfirmResponseData: Codable {
    let message: String?
}

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)
    case noData
    case notAuthenticated
    case tokenExpired
    case invalidCredentials
    case userAlreadyExists
    case invalidConfirmationCode
    case passwordRequirementsNotMet
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return message ?? "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .notAuthenticated:
            return "Not authenticated"
        case .tokenExpired:
            return "Session expired. Please sign in again."
        case .invalidCredentials:
            return "Invalid email or password"
        case .userAlreadyExists:
            return "An account with this email already exists"
        case .invalidConfirmationCode:
            return "Invalid or expired confirmation code"
        case .passwordRequirementsNotMet:
            return "Password does not meet requirements"
        case .unknownError(let message):
            return message
        }
    }
}


