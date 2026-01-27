//
//  ShareExtensionView.swift
//  GuidepostShare
//
//  Created by Cursor on 1/27/26.
//

import SwiftUI

struct ShareExtensionView: View {
    @Bindable var viewModel: ShareExtensionViewModel
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else if !viewModel.isAuthenticated {
                    notAuthenticatedView
                } else if viewModel.selectedImages.isEmpty {
                    noImagesView
                } else {
                    mainContentView
                }
            }
            .navigationTitle("Share to Guidepost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.cancelRequest()
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading images...")
                .foregroundStyle(.secondary)
        }
    }
    
    private var notAuthenticatedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("Sign In Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Please sign in to Guidepost to upload images.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                viewModel.openMainApp()
            }) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Open Guidepost")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
        }
        .padding()
    }
    
    private var noImagesView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("No Images Found")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Unable to load images from the share sheet.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Image preview section
            ScrollView {
                VStack(spacing: 16) {
                    // Image count
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundStyle(.blue)
                        Text("\(viewModel.selectedImages.count) image(s) selected")
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Image grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(viewModel.selectedImages) { imageInfo in
                            Image(uiImage: imageInfo.image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        }
                    }
                    
                    // Metadata info
                    if viewModel.selectedImages.contains(where: { $0.metadata?.hasLocation == true }) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Location data will be included")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    // Upload progress
                    if viewModel.isUploading {
                        VStack(spacing: 12) {
                            ProgressView(value: viewModel.uploadProgress)
                                .progressViewStyle(.linear)
                            
                            Text("Uploading \(viewModel.uploadedCount) of \(viewModel.selectedImages.count)...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Success message
                    if let successMessage = viewModel.successMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(successMessage)
                                .font(.caption)
                                .foregroundStyle(.green)
                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            
            // Upload button (pinned to bottom)
            if !viewModel.isUploading && viewModel.successMessage == nil {
                Button(action: {
                    Task {
                        await viewModel.uploadImages()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Upload & Analyze")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.063, green: 0.725, blue: 0.506), // #10B981
                                Color(red: 0.020, green: 0.588, blue: 0.412)  // #059669
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color(red: 0.020, green: 0.588, blue: 0.412).opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
            }
        }
    }
}
