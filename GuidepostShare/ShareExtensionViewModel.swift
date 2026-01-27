//
//  ShareExtensionViewModel.swift
//  GuidepostShare
//
//  Created by John Gambrell on 1/27/26.
//

import UIKit
import UniformTypeIdentifiers
import Photos

// MARK: - View Model

@Observable
@MainActor
class ShareExtensionViewModel {
    var selectedImages: [ShareImageInfo] = []
    var isLoading = true
    var isUploading = false
    var uploadProgress: Double = 0
    var uploadedCount = 0
    var errorMessage: String?
    var successMessage: String?
    var isAuthenticated = false
    
    private weak var extensionContext: NSExtensionContext?
    private let authService = AuthService.shared
    private let apiService = ImageAPIService.shared
    
    init(extensionContext: NSExtensionContext?) {
        self.extensionContext = extensionContext
        self.isAuthenticated = authService.isAuthenticated
    }
    
    func extractImages() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            isLoading = false
            errorMessage = "No items to share"
            return
        }
        
        var loadedImages: [ShareImageInfo] = []
        let group = DispatchGroup()
        
        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            
            for provider in attachments {
                // Check for image
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    group.enter()
                    
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (item, error) in
                        defer { group.leave() }
                        
                        if let error = error {
                            print("Error loading image: \(error.localizedDescription)")
                            return
                        }
                        
                        var image: UIImage?
                        var metadata: ImageMetadata?
                        
                        // Handle different item types
                        if let url = item as? URL {
                            // If it's a URL, load the image data
                            if let data = try? Data(contentsOf: url),
                               let loadedImage = UIImage(data: data) {
                                image = loadedImage
                                
                                // Try to extract metadata from the image
                                metadata = self?.extractMetadataFromData(data)
                            }
                        } else if let data = item as? Data,
                                  let loadedImage = UIImage(data: data) {
                            image = loadedImage
                            metadata = self?.extractMetadataFromData(data)
                        } else if let loadedImage = item as? UIImage {
                            image = loadedImage
                        }
                        
                        if let image = image {
                            let shareInfo = ShareImageInfo(image: image, metadata: metadata)
                            loadedImages.append(shareInfo)
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.selectedImages = loadedImages
            self?.isLoading = false
            
            if loadedImages.isEmpty {
                self?.errorMessage = "No images could be loaded"
            }
        }
    }
    
    private nonisolated func extractMetadataFromData(_ data: Data) -> ImageMetadata? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        
        var metadata = ImageMetadata()
        
        // Extract GPS data
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
               let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double {
                metadata.latitude = lat
                metadata.longitude = lon
                
                // Handle N/S and E/W reference
                if let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String, latRef == "S" {
                    metadata.latitude? *= -1
                }
                if let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String, lonRef == "W" {
                    metadata.longitude? *= -1
                }
            }
        }
        
        // Extract date from EXIF
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            metadata.creationDate = formatter.date(from: dateString)
        }
        
        return metadata.hasLocation || metadata.creationDate != nil ? metadata : nil
    }
    
    func uploadImages() async {
        guard isAuthenticated else {
            errorMessage = "Please sign in to Guidepost first"
            return
        }
        
        guard !selectedImages.isEmpty else {
            errorMessage = "No images to upload"
            return
        }
        
        isUploading = true
        errorMessage = nil
        successMessage = nil
        uploadedCount = 0
        uploadProgress = 0
        
        let totalImages = selectedImages.count
        
        for (index, imageInfo) in selectedImages.enumerated() {
            do {
                _ = try await apiService.uploadImage(imageInfo.image, metadata: imageInfo.metadata)
                uploadedCount += 1
                uploadProgress = Double(index + 1) / Double(totalImages)
            } catch {
                errorMessage = "Upload failed: \(error.localizedDescription)"
                isUploading = false
                return
            }
        }
        
        isUploading = false
        successMessage = "Successfully uploaded \(uploadedCount) image(s)!"
        
        // Close extension after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.completeRequest()
        }
    }
    
    func openMainApp() {
        guard let url = URL(string: "guidepost://") else { return }
        
        // Try to open the main app
        extensionContext?.open(url, completionHandler: { success in
            if success {
                DispatchQueue.main.async { [weak self] in
                    self?.cancelRequest()
                }
            }
        })
    }
    
    func cancelRequest() {
        extensionContext?.cancelRequest(withError: NSError(domain: "com.gambrell.Guidepost2026", code: 0, userInfo: nil))
    }
    
    func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

// MARK: - Share Image Info

struct ShareImageInfo: Identifiable {
    let id = UUID()
    let image: UIImage
    let metadata: ImageMetadata?
}
