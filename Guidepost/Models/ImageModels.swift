//
//  ImageModels.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import Foundation

// MARK: - API Response Models

struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let data: T?
}

// MARK: - Upload Service Models

struct UploadedImage: Codable, Identifiable {
    let id: String
    let filename: String
    let originalName: String
    let mimetype: String
    let size: Int
    let uploadedAt: String
    let path: String

    var uploadDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: uploadedAt)
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

struct ImagesListResponse: Codable {
    let success: Bool
    let data: [UploadedImage]
}

struct UploadResponse: Codable {
    let success: Bool
    let message: String
    let data: UploadedImage
}

// MARK: - Analysis Service Models

struct ImageAnalysisResult: Codable, Identifiable {
    let imageId: String
    let filename: String
    let analyzedAt: String
    let keywords: [String]?
    let detectedText: [String]?
    let description: String?
    let status: AnalysisStatus
    let error: String?

    var id: String { imageId }

    var analyzedDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: analyzedAt)
    }

    var searchableText: String {
        var components: [String] = []

        if let keywords = keywords {
            components.append(contentsOf: keywords)
        }
        if let description = description {
            components.append(description)
        }
        if let detectedText = detectedText {
            components.append(contentsOf: detectedText)
        }
        components.append(filename)

        return components.joined(separator: " ").lowercased()
    }
}

enum AnalysisStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed
}

struct AnalysisListResponse: Codable {
    let success: Bool
    let data: [ImageAnalysisResult]
}

struct AnalysisResponse: Codable {
    let success: Bool
    let data: ImageAnalysisResult
}
