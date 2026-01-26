//
//  ImageGridViewModel.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import Foundation
import UIKit
import Observation

@Observable
class ImageGridViewModel {
    var analysisResults: [ImageAnalysisResult] = []
    var imageInfoLookup: [String: ImageInfo] = [:]  // Lookup by imageId for location/date
    var imageCache: [String: UIImage] = [:]
    var errorMessage: String?
    var searchText = ""
    var isLoading: Bool = true

    private let apiService = ImageAPIService.shared
    private var loadTask: Task<Void, Never>?

    var filteredResults: [ImageAnalysisResult] {
        if searchText.isEmpty {
            return analysisResults
        }

        let lowercasedSearch = searchText.lowercased()
        return analysisResults.filter { result in
            result.searchableText.contains(lowercasedSearch)
        }
    }

    init() {
        // Load data once on initialization
        loadTask = Task {
            await loadAnalysisResults()
        }
    }

    func loadAnalysisResults() async {
        // Cancel any existing load task
        loadTask?.cancel()

        errorMessage = nil
        isLoading = true

        loadTask = Task {
            do {
                // Fetch both analysis results and image info in parallel
                async let analysisTask = apiService.fetchAllAnalysis()
                async let imagesTask = apiService.fetchAllImages()
                
                let (results, images) = try await (analysisTask, imagesTask)
                
                if !Task.isCancelled {
                    analysisResults = results
                    // Build lookup dictionary for image info (location/date)
                    imageInfoLookup = Dictionary(uniqueKeysWithValues: images.map { ($0.id, $0) })
                    isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }

        await loadTask?.value
    }
    
    /// Get image info (location/date) for an image
    func getImageInfo(for imageId: String) -> ImageInfo? {
        return imageInfoLookup[imageId]
    }

    func loadImageData(for imageId: String) async -> UIImage? {
        if let cachedImage = imageCache[imageId] {
            return cachedImage
        }

        do {
            let data = try await apiService.fetchImageData(id: imageId)
            if let image = UIImage(data: data) {
                imageCache[imageId] = image
                return image
            }
        } catch {
            print("Failed to load image: \(error.localizedDescription)")
        }

        return nil
    }

    func uploadImage(_ image: UIImage, metadata: ImageMetadata? = nil) async throws -> UploadedImage {
        let uploadedImage = try await apiService.uploadImage(image, metadata: metadata)
        imageCache[uploadedImage.id] = image
        // Refresh analysis results after upload to show new image once analyzed
        await loadAnalysisResults()
        return uploadedImage
    }

    func deleteImage(_ imageId: String) async throws {
        try await apiService.deleteImage(id: imageId)
        
        // Remove from local cache and results
        imageCache.removeValue(forKey: imageId)
        analysisResults.removeAll { $0.imageId == imageId }
    }
}
