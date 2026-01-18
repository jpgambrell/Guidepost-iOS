//
//  HomeView.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import SwiftUI

struct HomeView: View {
    @Environment(ImageGridViewModel.self) private var viewModel
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showUploadSheet = false
    @State private var showProfileSheet = false
    @State private var isRefreshing = false

    let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 8)
    ]

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
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

                // Bottom Bar with SearchBar and FAB
                HStack(spacing: 12) {
                    SearchBar(text: $viewModel.searchText)

                    FloatingActionButton(action: {
                        showUploadSheet = true
                    })
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Guidepost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showProfileSheet = true }) {
                        ProfileButton(user: authViewModel.currentUser)
                    }
                }
            }
            .sheet(isPresented: $showUploadSheet) {
                ImageUploadView()
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileSheetView()
            }
        }
    }
}

// MARK: - Profile Button

struct ProfileButton: View {
    let user: User?
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
            
            if let user = user {
                Text(user.givenName.prefix(1).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Profile Sheet View

struct ProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Profile header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: .cyan.opacity(0.4), radius: 10)
                        
                        if let user = authViewModel.currentUser {
                            Text(user.givenName.prefix(1).uppercased() + user.familyName.prefix(1).uppercased())
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                        }
                    }
                    
                    if let user = authViewModel.currentUser {
                        VStack(spacing: 4) {
                            Text(user.fullName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            if user.role == .admin {
                                Text("Administrator")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.purple)
                                    )
                                    .padding(.top, 4)
                            }
                        }
                    } else {
                        Text("Loading profile...")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 20)
                
                Divider()
                    .padding(.horizontal)
                
                // Account section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Account")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    Button(action: { showLogoutConfirmation = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18))
                                .frame(width: 28)
                            
                            Text("Sign Out")
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // App version
                Text("Guidepost v1.0.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Sign Out",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.8))
                .font(.system(size: 16, weight: .medium))

            TextField("Search images...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundStyle(.white)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.6))
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // Outer glow
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 10)

                // Glass layer
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            }
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .shadow(color: .blue.opacity(0.2), radius: 15, x: 0, y: 8)
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
                    .frame(width: 125, height: 125)
                    .overlay {
                        ProgressView()
                    }
            }

            // Processing overlay
            if analysisResult.status == .processing {
                Text("Processing")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .orange.opacity(0.4), radius: 4, x: 0, y: 2)
                    .padding(.bottom, 6)
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
                // Outer glow
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .blur(radius: 5)

                // Glass circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.6), Color.white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.4))
                            .frame(width: 50, height: 50)
                    )

                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
}

#Preview {
    HomeView()
        .environment(ImageGridViewModel())
        .environment(AuthViewModel())
}
