//
//  ImageUploadView.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import AVFoundation
import CoreLocation
import Photos
import PhotosUI
import SwiftUI

// MARK: - Location Manager for Camera Captures

@Observable
@MainActor
class CameraLocationManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            self.currentLocation = location
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startUpdatingLocation()
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error.localizedDescription)")
    }
}

struct ImageUploadView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ImageGridViewModel.self) private var viewModel

    @State private var selectedImage: UIImage?
    @State private var selectedMetadata: ImageMetadata?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showSuccessMessage = false
    @State private var showPermissionAlert = false
    @State private var showPhotoPermissionAlert = false
    @State private var showLocationPermissionAlert = false
    
    @State private var locationManager = CameraLocationManager()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 80))
                            .foregroundStyle(.gray)

                        Text("No image selected")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(spacing: 12) {
                    Button(action: checkCameraPermission) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Take Photo")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }

                    Button(action: checkPhotoLibraryPermission) {
                        HStack {
                            Image(systemName: "photo.fill")
                            Text("Choose from Library")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal)

                if let error = uploadError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
                
                // Upload button pinned to bottom
                if selectedImage != nil {
                    Button(action: uploadImage) {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                Text("Upload & Analyze")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: isUploading ? [Color.gray, Color.gray] : [
                                    Color(red: 0.063, green: 0.725, blue: 0.506), // #10B981
                                    Color(red: 0.020, green: 0.588, blue: 0.412)  // #059669
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: isUploading ? Color.clear : Color(red: 0.020, green: 0.588, blue: 0.412).opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .disabled(isUploading)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .padding()
            .navigationTitle("Upload Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(
                    sourceType: .camera,
                    selectedImage: $selectedImage,
                    selectedMetadata: $selectedMetadata,
                    fallbackLocation: locationManager.currentLocation
                )
            }
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(
                    sourceType: .photoLibrary,
                    selectedImage: $selectedImage,
                    selectedMetadata: $selectedMetadata,
                    fallbackLocation: nil
                )
            }
            .alert("Success!", isPresented: $showSuccessMessage) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Image uploaded and sent for analysis!")
            }
            .alert("Camera Permission Required", isPresented: $showPermissionAlert) {
                Button("Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable camera access in Settings to take photos.")
            }
            .alert("Photo Library Permission Required", isPresented: $showPhotoPermissionAlert) {
                Button("Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable full photo library access in Settings to select photos.")
            }
            .alert("Location Permission Recommended", isPresented: $showLocationPermissionAlert) {
                Button("Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Continue Without Location", role: .cancel) {}
            } message: {
                Text("Location access is recommended to capture where your photos were taken. You can enable it in Settings.")
            }

        }
    }

    private func uploadImage() {
        guard let image = selectedImage else { return }

        isUploading = true
        uploadError = nil

        Task {
            do {
                _ = try await viewModel.uploadImage(image, metadata: selectedMetadata)
                showSuccessMessage = true
            } catch {
                uploadError = error.localizedDescription
            }
            isUploading = false
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Also ensure location permission for geotagging camera photos
            ensureLocationPermissionAndShowCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        ensureLocationPermissionAndShowCamera()
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert = true
        @unknown default:
            break
        }
    }
    
    private func ensureLocationPermissionAndShowCamera() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            showCamera = true
        case .notDetermined:
            locationManager.requestPermission()
            // Show camera anyway, location will be captured if permission granted
            showCamera = true
        case .denied, .restricted:
            // Show alert but still allow camera use (just won't have location)
            showLocationPermissionAlert = true
            showCamera = true
        @unknown default:
            showCamera = true
        }
    }
    
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            showPhotoPicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        showPhotoPicker = true
                    } else {
                        showPhotoPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showPhotoPermissionAlert = true
        @unknown default:
            break
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Binding var selectedMetadata: ImageMetadata?
    let fallbackLocation: CLLocation?  // Used for camera when EXIF GPS is not available
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            
            // Extract metadata based on source type
            var metadata = ImageMetadata()
            
            if parent.sourceType == .photoLibrary {
                // Extract metadata from PHAsset for photo library
                if let asset = info[.phAsset] as? PHAsset {
                    let location = asset.location
                    metadata.latitude = location?.coordinate.latitude
                    metadata.longitude = location?.coordinate.longitude
                    metadata.creationDate = asset.creationDate
                }
            } else if parent.sourceType == .camera {
                // Extract metadata from EXIF for camera
                var hasExifLocation = false
                
                if let mediaMetadata = info[.mediaMetadata] as? [String: Any] {
                    // GPS data in {GPS} dictionary
                    if let gps = mediaMetadata["{GPS}"] as? [String: Any] {
                        if let lat = gps["Latitude"] as? Double,
                           let lon = gps["Longitude"] as? Double {
                            metadata.latitude = lat
                            metadata.longitude = lon
                            hasExifLocation = true
                            // Handle N/S and E/W reference
                            if let latRef = gps["LatitudeRef"] as? String, latRef == "S" {
                                metadata.latitude? *= -1
                            }
                            if let lonRef = gps["LongitudeRef"] as? String, lonRef == "W" {
                                metadata.longitude? *= -1
                            }
                        }
                    }
                    // Date from {Exif} dictionary
                    if let exif = mediaMetadata["{Exif}"] as? [String: Any],
                       let dateString = exif["DateTimeOriginal"] as? String {
                        // Parse EXIF date format: "yyyy:MM:dd HH:mm:ss"
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                        metadata.creationDate = formatter.date(from: dateString)
                    }
                }
                
                // Fallback: Use CoreLocation if EXIF GPS is not available
                if !hasExifLocation, let fallbackLocation = parent.fallbackLocation {
                    metadata.latitude = fallbackLocation.coordinate.latitude
                    metadata.longitude = fallbackLocation.coordinate.longitude
                }
                
                // If no EXIF date, use current time for camera captures
                if metadata.creationDate == nil {
                    metadata.creationDate = Date()
                }
            }
            
            parent.selectedMetadata = metadata
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
