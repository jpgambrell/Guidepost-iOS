//
//  ImageUploadView.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import AVFoundation
import Photos
import PhotosUI
import SwiftUI

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
                ImagePicker(sourceType: .camera, selectedImage: $selectedImage, selectedMetadata: $selectedMetadata)
            }
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage, selectedMetadata: $selectedMetadata)
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
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        showCamera = true
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert = true
        @unknown default:
            break
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
                if let mediaMetadata = info[.mediaMetadata] as? [String: Any] {
                    // GPS data in {GPS} dictionary
                    if let gps = mediaMetadata["{GPS}"] as? [String: Any] {
                        metadata.latitude = gps["Latitude"] as? Double
                        metadata.longitude = gps["Longitude"] as? Double
                        // Handle N/S and E/W reference
                        if let latRef = gps["LatitudeRef"] as? String, latRef == "S" {
                            metadata.latitude? *= -1
                        }
                        if let lonRef = gps["LongitudeRef"] as? String, lonRef == "W" {
                            metadata.longitude? *= -1
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
            }
            
            parent.selectedMetadata = metadata
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
