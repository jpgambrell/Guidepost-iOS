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
    
    // Adaptive grid state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var columnCount: Int = 3
    @State private var lastColumnCount: Int = 3
    
    // Delete mode state
    @State private var imageToDelete: String? = nil
    @State private var deletedImages: Set<String> = []
    
    // Navigation state
    @State private var selectedImageForNavigation: ImageAnalysisResult? = nil
    
    // Define zoom levels for snapping
    private let zoomLevels: [(scale: CGFloat, columns: Int)] = [
        (0.6, 5),  // Most zoomed out
        (1.0, 3),  // Default
        (1.8, 2),  // Medium
        (3.0, 1)   // Single column
    ]
    
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    // Computed properties for adaptive grid
    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: spacing),
            count: columnCount
        )
    }
    
    private var spacing: CGFloat {
        columnCount == 1 ? 2 : 1
    }
    
    // Magnification gesture
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                
                let newScale = min(max(scale * delta, 0.5), 4.0)
                scale = newScale
                
                let newColumns = columnsForScale(newScale)
                if newColumns != lastColumnCount {
                    // Provide haptic feedback on column change
                    hapticFeedback.impactOccurred()
                    
                    withAnimation(.easeInOut(duration: 0.15)) {
                        columnCount = newColumns
                    }
                    lastColumnCount = newColumns
                }
            }
            .onEnded { _ in
                lastScale = 1.0
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    let snapped = snapToNearestLevel(scale)
                    scale = snapped.scale
                    columnCount = snapped.columns
                    lastColumnCount = snapped.columns
                }
            }
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    if viewModel.isLoading {
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
                                    deletedImages.removeAll()
                                    imageToDelete = nil
                                    isRefreshing = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isRefreshing)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.filteredResults.isEmpty {
                        ScrollView {
                            VStack(spacing: 16) {
                                Spacer()
                                    .frame(height: 100)
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
                                    Text("Pull down to refresh")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .padding(.top, 8)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                        .refreshable {
                            isRefreshing = true
                            await viewModel.loadAnalysisResults()
                            deletedImages.removeAll()
                            imageToDelete = nil
                            isRefreshing = false
                        }
                    } else {
                        ScrollView {
                            LazyVGrid(columns: gridColumns, spacing: spacing) {
                                ForEach(viewModel.filteredResults) { result in
                                    if !deletedImages.contains(result.imageId) {
                                        ImageGridCellWithDelete(
                                            analysisResult: result,
                                            columnCount: columnCount,
                                            isDeleteVisible: imageToDelete == result.imageId,
                                            onLongPress: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    if imageToDelete == result.imageId {
                                                        imageToDelete = nil
                                                    } else {
                                                        imageToDelete = result.imageId
                                                    }
                                                }
                                            },
                                            onDelete: {
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                    deletedImages.insert(result.imageId)
                                                    imageToDelete = nil
                                                }
                                                // TODO: Call delete API endpoint here
                                            },
                                            onNavigate: {
                                                selectedImageForNavigation = result
                                            }
                                        )
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .scale(scale: 0.5).combined(with: .opacity)
                                        ))
                                    }
                                }
                            }
                            .padding(.top, 6)
                            .animation(.easeInOut(duration: 0.2), value: columnCount)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: deletedImages)
                        }
                        .ignoresSafeArea(.container, edges: [.bottom])
                        .simultaneousGesture(magnificationGesture)
                        .refreshable {
                            isRefreshing = true
                            await viewModel.loadAnalysisResults()
                            deletedImages.removeAll()
                            imageToDelete = nil
                            isRefreshing = false
                        }
                        .onTapGesture {
                            // Dismiss delete button when tapping empty space
                            if imageToDelete != nil {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    imageToDelete = nil
                                }
                            }
                        }
                        .navigationDestination(item: $selectedImageForNavigation) { result in
                            ImageDetailDestination(analysisResult: result)
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
        .overlay(alignment: .topTrailing) {
            Button(action: { showProfileSheet = true }) {
                ProfileButton(user: authViewModel.currentUser)
            }
            .padding(.trailing, 16)
            .padding(.top, 12)
        }
            .sheet(isPresented: $showUploadSheet, onDismiss: {
                // Refresh analysis results when upload sheet is dismissed
                Task {
                    await viewModel.loadAnalysisResults()
                }
            }) {
                ImageUploadView()
            }
            .sheet(isPresented: $showProfileSheet) {
                ProfileSheetView()
            }
        }
        .onAppear {
            hapticFeedback.prepare()
        }
    }
    
    // MARK: - Helper Functions
    
    private func columnsForScale(_ scale: CGFloat) -> Int {
        for (index, level) in zoomLevels.enumerated() {
            if index == zoomLevels.count - 1 {
                return level.columns
            }
            let nextLevel = zoomLevels[index + 1]
            let midpoint = (level.scale + nextLevel.scale) / 2
            if scale < midpoint {
                return level.columns
            }
        }
        return zoomLevels.last?.columns ?? 3
    }
    
    private func snapToNearestLevel(_ scale: CGFloat) -> (scale: CGFloat, columns: Int) {
        var closest = zoomLevels[0]
        var minDistance = abs(scale - closest.scale)
        
        for level in zoomLevels {
            let distance = abs(scale - level.scale)
            if distance < minDistance {
                minDistance = distance
                closest = level
            }
        }
        return closest
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
    @Environment(AppearanceManager.self) private var appearanceManager
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        @Bindable var appearanceManager = appearanceManager
        
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
                
                // Appearance section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 8) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Button(action: {
                                appearanceManager.selectedAppearance = mode
                            }) {
                                HStack {
                                    Image(systemName: mode.iconName)
                                        .font(.system(size: 18))
                                        .frame(width: 28)
                                        .foregroundStyle(appearanceManager.selectedAppearance == mode ? Color.theme.accent : .secondary)
                                    
                                    Text(mode.displayName)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    if appearanceManager.selectedAppearance == mode {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.theme.accent)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(appearanceManager.selectedAppearance == mode ? Color.theme.accent.opacity(0.1) : Color.secondary.opacity(0.1))
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.theme.textSecondary)
                .font(.system(size: 16, weight: .medium))

            TextField("Search images...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundStyle(Color.theme.textPrimary)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.theme.textSecondary)
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
                                    colors: colorScheme == .dark ? [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05)
                                    ] : [
                                        Color.black.opacity(0.05),
                                        Color.black.opacity(0.02)
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
                                    colors: colorScheme == .dark ? [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1)
                                    ] : [
                                        Color.black.opacity(0.2),
                                        Color.black.opacity(0.05)
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
    let columnCount: Int
    @Environment(ImageGridViewModel.self) private var viewModel
    @State private var loadedImage: UIImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if let uiImage = loadedImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width, height: geometry.size.width)
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
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            loadedImage = await viewModel.loadImageData(for: analysisResult.imageId)
        }
    }
}

// MARK: - Image Grid Cell With Delete

struct ImageGridCellWithDelete: View {
    let analysisResult: ImageAnalysisResult
    let columnCount: Int
    let isDeleteVisible: Bool
    let onLongPress: () -> Void
    let onDelete: () -> Void
    let onNavigate: () -> Void
    
    @Environment(ImageGridViewModel.self) private var viewModel
    @State private var loadedImage: UIImage?
    @State private var isPressed = false
    @State private var didTriggerLongPress = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                imageContent(geometry: geometry)
                    .onLongPressGesture(
                        minimumDuration: 0.5,
                        maximumDistance: 10,
                        pressing: { isPressing in
                            isPressed = isPressing
                        },
                        perform: {
                            didTriggerLongPress = true
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            onLongPress()
                            DispatchQueue.main.async {
                                didTriggerLongPress = false
                            }
                        }
                    )
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                guard !didTriggerLongPress else { return }
                                if isDeleteVisible {
                                    onLongPress()
                                } else {
                                    onNavigate()
                                }
                            }
                    )
                
                // Delete button
                if isDeleteVisible {
                    Button(action: onDelete) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 26, height: 26)
                                .shadow(color: .red.opacity(0.5), radius: 4, x: 0, y: 2)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(6)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(1)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            loadedImage = await viewModel.loadImageData(for: analysisResult.imageId)
        }
    }
    
    @ViewBuilder
    private func imageContent(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .bottom) {
            if let uiImage = loadedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: geometry.size.width, height: geometry.size.width)
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
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .scaleEffect(isDeleteVisible ? 0.92 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDeleteVisible)
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
    @Environment(\.colorScheme) var colorScheme

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
                                    colors: colorScheme == .dark ? [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.2)
                                    ] : [
                                        Color.black.opacity(0.3),
                                        Color.black.opacity(0.1)
                                    ],
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
