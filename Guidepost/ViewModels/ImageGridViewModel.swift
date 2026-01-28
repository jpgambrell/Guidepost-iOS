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
    var isLoading: Bool = true  // Start true so HomeView shows loading state initially
    
    /// Track whether initial load has been performed
    private var hasPerformedInitialLoad = false

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
        // Don't load data in init - wait for HomeView to appear
        // This prevents race conditions when user isn't authenticated yet
    }
    
    /// Load analysis results if not already loaded
    /// Call this from HomeView.task to ensure user is authenticated first
    func loadIfNeeded() async {
        guard !hasPerformedInitialLoad else { return }
        hasPerformedInitialLoad = true
        await loadAnalysisResults()
    }
    
    /// Clear all cached data - call this on sign out to prevent data leaking between users
    func clearAllData() {
        loadTask?.cancel()
        loadTask = nil
        analysisResults = []
        imageInfoLookup = [:]
        imageCache = [:]
        errorMessage = nil
        searchText = ""
        isLoading = true  // Reset to initial state for next user
        hasPerformedInitialLoad = false  // Allow fresh load for next user
    }

    func loadAnalysisResults() async {
        // Cancel any existing load task
        loadTask?.cancel()

        errorMessage = nil
        isLoading = true
        
        // Keep track of local placeholders (processing images not yet on server)
        let localPlaceholders = analysisResults.filter { $0.status == .processing }

        loadTask = Task {
            do {
                // Fetch both analysis results and image info in parallel
                async let analysisTask = apiService.fetchAllAnalysis()
                async let imagesTask = apiService.fetchAllImages()
                
                let (results, images) = try await (analysisTask, imagesTask)
                
                if !Task.isCancelled {
                    // Build set of server image IDs for quick lookup
                    let serverImageIds = Set(results.map { $0.imageId })
                    
                    // Keep local placeholders that aren't in the server response yet
                    let orphanedPlaceholders = localPlaceholders.filter { !serverImageIds.contains($0.imageId) }
                    
                    // Merge: server results + orphaned placeholders (placeholders at the beginning)
                    analysisResults = orphanedPlaceholders + results
                    
                    // Build lookup dictionary for image info (location/date)
                    // Preserve local image info for orphaned placeholders
                    var newLookup = Dictionary(uniqueKeysWithValues: images.map { ($0.id, $0) })
                    for placeholder in orphanedPlaceholders {
                        if let existingInfo = imageInfoLookup[placeholder.imageId] {
                            newLookup[placeholder.imageId] = existingInfo
                        }
                    }
                    imageInfoLookup = newLookup
                    
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
        
        // Immediately add placeholder to show the image right away
        let placeholder = ImageAnalysisResult(placeholder: uploadedImage)
        let imageInfo = ImageInfo(from: uploadedImage, metadata: metadata)
        
        // Insert at the beginning of the list so it appears first
        analysisResults.insert(placeholder, at: 0)
        imageInfoLookup[uploadedImage.id] = imageInfo
        imageCache[uploadedImage.id] = image
        
        // Schedule a background refresh to get the actual server data
        // Use a small delay to allow the server to process the upload
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await loadAnalysisResults()
        }
        
        return uploadedImage
    }

    func deleteImage(_ imageId: String) async throws {
        try await apiService.deleteImage(id: imageId)
        
        // Remove from local cache and results
        imageCache.removeValue(forKey: imageId)
        analysisResults.removeAll { $0.imageId == imageId }
    }
}
