//
//  ImageAPIService.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import Foundation
import UIKit

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)
    case noData
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .unauthorized:
            return "Unauthorized - please sign in again"
        }
    }
}

class ImageAPIService {
    static let shared = ImageAPIService()

    private let uploadServiceURL = "https://0p19v2252j.execute-api.us-east-1.amazonaws.com/prod"
    private let analysisServiceURL = "https://0p19v2252j.execute-api.us-east-1.amazonaws.com/prod"
    private let session: URLSession
    private let authService = AuthService.shared

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Authorization Helper
    
    private func addAuthorizationHeader(to request: inout URLRequest) async throws {
        let token = try await authService.ensureValidToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    private func handleUnauthorizedIfNeeded(statusCode: Int) throws {
        if statusCode == 401 {
            authService.clearTokens()
            throw APIError.unauthorized
        }
    }
    
    // MARK: - Debug Logging
    
    private func logRequest(_ request: URLRequest) {
        #if DEBUG
        print("📷 Request URL: \(request.url?.absoluteString ?? "nil")")
        print("📷 Request Method: \(request.httpMethod ?? "nil")")
        // Don't log full Authorization header for security, just indicate presence
        if let headers = request.allHTTPHeaderFields {
            var safeHeaders = headers
            if safeHeaders["Authorization"] != nil {
                safeHeaders["Authorization"] = "Bearer [REDACTED]"
            }
            print("📷 Request Headers: \(safeHeaders)")
        }
        if let body = request.httpBody, body.count < 1000, let bodyString = String(data: body, encoding: .utf8) {
            print("📷 Request Body: \(bodyString)")
        } else if let body = request.httpBody {
            print("📷 Request Body: [\(body.count) bytes]")
        }
        #endif
    }
    
    private func logResponse(_ response: HTTPURLResponse, data: Data) {
        #if DEBUG
        print("📷 Response Status: \(response.statusCode)")
        if data.count < 2000, let responseString = String(data: data, encoding: .utf8) {
            print("📷 Response Body: \(responseString)")
        } else {
            print("📷 Response Body: [\(data.count) bytes]")
        }
        #endif
    }

    // MARK: - Upload Image

    func uploadImage(_ image: UIImage, metadata: ImageMetadata? = nil) async throws -> UploadedImage {
        guard let url = URL(string: "\(uploadServiceURL)/api/upload") else {
            throw APIError.invalidURL
        }

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw APIError.invalidResponse
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header
        try await addAuthorizationHeader(to: &request)

        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add metadata fields if available
        if let metadata = metadata {
            if let lat = metadata.latitude {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"latitude\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(lat)\r\n".data(using: .utf8)!)
            }
            if let lon = metadata.longitude {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"longitude\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(lon)\r\n".data(using: .utf8)!)
            }
            if let date = metadata.creationDate {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let dateString = formatter.string(from: date)
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"creationDate\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(dateString)\r\n".data(using: .utf8)!)
            }
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body
        
        logRequest(request)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            logResponse(httpResponse, data: data)

            try handleUnauthorizedIfNeeded(statusCode: httpResponse.statusCode)
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let uploadResponse = try decoder.decode(UploadResponse.self, from: data)

            return uploadResponse.data
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            #if DEBUG
            print("📷 Decoding Error: \(error)")
            #endif
            throw APIError.decodingError(error)
        } catch {
            #if DEBUG
            print("📷 Network Error: \(error)")
            #endif
            throw APIError.networkError(error)
        }
    }

    // MARK: - Fetch All Analysis Results

    func fetchAllAnalysis() async throws -> [ImageAnalysisResult] {
        guard let url = URL(string: "\(analysisServiceURL)/api/analysis") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add authorization header
        try await addAuthorizationHeader(to: &request)
        
        logRequest(request)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            logResponse(httpResponse, data: data)

            try handleUnauthorizedIfNeeded(statusCode: httpResponse.statusCode)
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let listResponse = try decoder.decode(AnalysisListResponse.self, from: data)

            return listResponse.data
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            #if DEBUG
            print("📷 Decoding Error: \(error)")
            #endif
            throw APIError.decodingError(error)
        } catch {
            #if DEBUG
            print("📷 Network Error: \(error)")
            #endif
            throw APIError.networkError(error)
        }
    }

    // MARK: - Fetch Analysis for Specific Image

    func fetchAnalysis(imageId: String) async throws -> ImageAnalysisResult {
        guard let url = URL(string: "\(analysisServiceURL)/api/analysis/\(imageId)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add authorization header
        try await addAuthorizationHeader(to: &request)
        
        logRequest(request)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            logResponse(httpResponse, data: data)

            try handleUnauthorizedIfNeeded(statusCode: httpResponse.statusCode)
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let analysisResponse = try decoder.decode(AnalysisResponse.self, from: data)

            return analysisResponse.data
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            #if DEBUG
            print("📷 Decoding Error: \(error)")
            #endif
            throw APIError.decodingError(error)
        } catch {
            #if DEBUG
            print("📷 Network Error: \(error)")
            #endif
            throw APIError.networkError(error)
        }
    }

    // MARK: - Fetch Image Data

    func fetchImageData(id: String) async throws -> Data {
        guard let url = URL(string: "\(uploadServiceURL)/api/images/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add authorization header
        try await addAuthorizationHeader(to: &request)
        
        logRequest(request)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            #if DEBUG
            print("📷 Response Status: \(httpResponse.statusCode)")
            print("📷 Response Body: [Image data - \(data.count) bytes]")
            #endif

            try handleUnauthorizedIfNeeded(statusCode: httpResponse.statusCode)
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }

            return data
        } catch let error as APIError {
            throw error
        } catch {
            #if DEBUG
            print("📷 Network Error: \(error)")
            #endif
            throw APIError.networkError(error)
        }
    }

    // MARK: - Delete Image

    func deleteImage(id: String) async throws {
        guard let url = URL(string: "\(uploadServiceURL)/api/images/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        // Add authorization header
        try await addAuthorizationHeader(to: &request)
        
        logRequest(request)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            logResponse(httpResponse, data: data)

            try handleUnauthorizedIfNeeded(statusCode: httpResponse.statusCode)
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch {
            #if DEBUG
            print("📷 Network Error: \(error)")
            #endif
            throw APIError.networkError(error)
        }
    }

    // MARK: - Health Check

    func healthCheckUploadService() async throws -> Bool {
        guard let url = URL(string: "\(uploadServiceURL)/health") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let healthResponse = try decoder.decode([String: AnyCodable].self, from: data)

            return healthResponse["success"]?.value as? Bool ?? false
        } catch {
            return false
        }
    }

    func healthCheckAnalysisService() async throws -> Bool {
        guard let url = URL(string: "\(analysisServiceURL)/health") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            let healthResponse = try decoder.decode([String: AnyCodable].self, from: data)

            return healthResponse["success"]?.value as? Bool ?? false
        } catch {
            return false
        }
    }
}

// MARK: - Helper for Dynamic JSON Decoding

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        }
    }
}
