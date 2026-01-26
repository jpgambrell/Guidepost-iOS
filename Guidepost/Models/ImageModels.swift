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

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        data = try container.decodeIfPresent(T.self, forKey: .data)
    }
}

// MARK: - Image Metadata

struct ImageMetadata {
    var latitude: Double?
    var longitude: Double?
    var creationDate: Date?
    
    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }
}

// MARK: - Upload Service Models

struct UploadedImage: Codable, Identifiable {
    let id: String
    let userId: String
    let filename: String
    let originalName: String
    let mimetype: String
    let size: Int
    let uploadedAt: String
    let path: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case filename
        case originalName
        case mimetype
        case size
        case uploadedAt
        case path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        filename = try container.decode(String.self, forKey: .filename)
        originalName = try container.decode(String.self, forKey: .originalName)
        mimetype = try container.decode(String.self, forKey: .mimetype)
        size = try container.decode(Int.self, forKey: .size)
        uploadedAt = try container.decode(String.self, forKey: .uploadedAt)
        path = try container.decode(String.self, forKey: .path)
    }

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

    enum CodingKeys: String, CodingKey {
        case success
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        data = try container.decode([UploadedImage].self, forKey: .data)
    }
}

struct UploadResponse: Codable {
    let success: Bool
    let message: String
    let data: UploadedImage

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decode(String.self, forKey: .message)
        data = try container.decode(UploadedImage.self, forKey: .data)
    }
}

// MARK: - Analysis Service Models

struct ImageAnalysisResult: Codable, Identifiable, Hashable {
    let imageId: String
    let userId: String
    let filename: String
    let analyzedAt: String
    let keywords: [String]?
    let detectedText: [String]?
    let description: String?
    let status: AnalysisStatus
    let error: String?

    enum CodingKeys: String, CodingKey {
        case imageId
        case userId
        case filename
        case analyzedAt
        case keywords
        case detectedText
        case description
        case status
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageId = try container.decode(String.self, forKey: .imageId)
        userId = try container.decode(String.self, forKey: .userId)
        filename = try container.decode(String.self, forKey: .filename)
        analyzedAt = try container.decode(String.self, forKey: .analyzedAt)
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords)
        detectedText = try container.decodeIfPresent([String].self, forKey: .detectedText)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        status = try container.decode(AnalysisStatus.self, forKey: .status)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }

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

    enum CodingKeys: String, CodingKey {
        case success
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        data = try container.decode([ImageAnalysisResult].self, forKey: .data)
    }
}

struct AnalysisResponse: Codable {
    let success: Bool
    let data: ImageAnalysisResult

    enum CodingKeys: String, CodingKey {
        case success
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        data = try container.decode(ImageAnalysisResult.self, forKey: .data)
    }
}
