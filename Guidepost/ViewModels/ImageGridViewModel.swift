//
//  ImageGridViewModel.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import Foundation
import UIKit
import Combine

@MainActor
class ImageGridViewModel: ObservableObject {
    @Published var analysisResults: [ImageAnalysisResult] = []
    @Published var imageCache: [String: UIImage] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""

    private let apiService = ImageAPIService.shared

    var filteredResults: [ImageAnalysisResult] {
        if searchText.isEmpty {
            return analysisResults
        }

        let lowercasedSearch = searchText.lowercased()
        return analysisResults.filter { result in
            result.searchableText.contains(lowercasedSearch)
        }
    }

    func loadAnalysisResults() async {
        isLoading = true
        errorMessage = nil

        do {
            analysisResults = try await apiService.fetchAllAnalysis()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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

    func refreshAnalysisResults() async {
        await loadAnalysisResults()
    }

    func uploadImage(_ image: UIImage) async throws -> UploadedImage {
        let uploadedImage = try await apiService.uploadImage(image)
        imageCache[uploadedImage.id] = image
        // Refresh analysis results after upload to show new image once analyzed
        await loadAnalysisResults()
        return uploadedImage
    }
}
