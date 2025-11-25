//
//  HomeView.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import SwiftUI

struct HomeView: View {
    @Environment(ImageGridViewModel.self) private var viewModel
    @State private var showUploadSheet = false
    @State private var isRefreshing = false

    let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 8)
    ]

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    SearchBar(text: $viewModel.searchText)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    if viewModel.analysisResults.isEmpty && viewModel.errorMessage == nil {
                        ProgressView("Loading images...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundStyle(.orange)
                            Text("Error loading analysis results")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task {
                                    isRefreshing = true
                                    await viewModel.loadAnalysisResults()
                                    isRefreshing = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isRefreshing)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.filteredResults.isEmpty {
                        VStack(spacing: 16) {
                            Image(
                                systemName: viewModel.searchText.isEmpty
                                    ? "photo.on.rectangle.angled" : "magnifyingglass"
                            )
                            .font(.system(size: 50))
                            .foregroundStyle(.gray)
                            Text(
                                viewModel.searchText.isEmpty
                                    ? "No images yet" : "No matching images"
                            )
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            if viewModel.searchText.isEmpty {
                                Text("Tap the + button to upload your first image")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(viewModel.filteredResults) { result in
                                    NavigationLink(
                                        destination: ImageDetailDestination(analysisResult: result)
                                    ) {
                                        ImageGridCell(analysisResult: result)
                                    }
                                }
                            }
                        }
                        .refreshable {
                            isRefreshing = true
                            await viewModel.loadAnalysisResults()
                            isRefreshing = false
                        }
                    }
                }
                .navigationTitle("Guidepost")
                .navigationBarTitleDisplayMode(.large)

                FloatingActionButton(action: {
                    showUploadSheet = true
                })
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .sheet(isPresented: $showUploadSheet) {
                ImageUploadView()
            }
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.gray)

            TextField("Search images...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding(8)
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Image Grid Cell

struct ImageGridCell: View {
    let analysisResult: ImageAnalysisResult
    @Environment(ImageGridViewModel.self) private var viewModel
    @State private var loadedImage: UIImage?

    var body: some View {
        ZStack(alignment: .bottom) {
            if let uiImage = loadedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 125, height: 125)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .overlay {
                        ProgressView()
                    }
            }

            // Processing overlay
            if analysisResult.status == .processing {
                Text("Processing")
                    .font(.caption2)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.bottom, 4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            loadedImage = await viewModel.loadImageData(for: analysisResult.imageId)
        }
    }
}

// MARK: - Image Detail Destination

struct ImageDetailDestination: View {
    let analysisResult: ImageAnalysisResult
    @Environment(ImageGridViewModel.self) private var viewModel
    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let uiImage = loadedImage {
                ImageDetailView(analysisResult: analysisResult, uiImage: uiImage)
            } else {
                ProgressView("Loading image...")
            }
        }
        .task {
            loadedImage = await viewModel.loadImageData(for: analysisResult.imageId)
        }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)

                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(ImageGridViewModel())
}
