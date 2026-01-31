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
    @State private var showDeleteConfirmation = false
    @State private var imageIdPendingDeletion: String? = nil
    
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
                                                imageIdPendingDeletion = result.imageId
                                                showDeleteConfirmation = true
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
            .confirmationDialog(
                "Delete Image",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let imageId = imageIdPendingDeletion else { return }
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        deletedImages.insert(imageId)
                        imageToDelete = nil
                    }
                    
                    Task {
                        do {
                            try await viewModel.deleteImage(imageId)
                        } catch {
                            // If delete fails, remove from deletedImages to show it again
                            _ = withAnimation {
                                deletedImages.remove(imageId)
                            }
                            print("Failed to delete image: \(error.localizedDescription)")
                        }
                    }
                    
                    imageIdPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    imageIdPendingDeletion = nil
                }
            } message: {
                Text("This action cannot be undone. The image and all associated data will be permanently deleted.")
            }
        }
        .onAppear {
            hapticFeedback.prepare()
        }
        .task {
            // Load data when HomeView appears (user is authenticated at this point)
            await viewModel.loadIfNeeded()
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
                        colors: [
                            Color(red: 0.063, green: 0.725, blue: 0.506), // #10B981
                            Color(red: 0.020, green: 0.588, blue: 0.412)  // #059669
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
            
            Image(systemName: "person.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Profile Sheet View

struct ProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(AppearanceManager.self) private var appearanceManager
    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showUpgradeSheet = false
    @State private var isDeleting = false
    
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
                                    colors: authViewModel.isGuest ? [
                                        Color.gray,
                                        Color.gray.opacity(0.7)
                                    ] : [
                                        Color(red: 0.063, green: 0.725, blue: 0.506), // #10B981
                                        Color(red: 0.020, green: 0.588, blue: 0.412)  // #059669
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(color: authViewModel.isGuest ? Color.gray.opacity(0.4) : Color(red: 0.020, green: 0.588, blue: 0.412).opacity(0.4), radius: 10)
                        
                        Image(systemName: authViewModel.isGuest ? "person.fill.questionmark" : "person.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                    }
                    
                    if authViewModel.isGuest {
                        VStack(spacing: 4) {
                            Text("Guest User")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("\(authViewModel.remainingGuestUploads) uploads remaining")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text("Trial Mode")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.orange)
                                )
                                .padding(.top, 4)
                        }
                    } else if let user = authViewModel.currentUser {
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
                    
                    // Upgrade Account button (for guests only)
                    if authViewModel.isGuest {
                        Button(action: { showUpgradeSheet = true }) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 18))
                                    .frame(width: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Full Account")
                                        .fontWeight(.medium)
                                    Text("Keep your images and unlock unlimited uploads")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .foregroundStyle(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.063, green: 0.725, blue: 0.506), // #10B981
                                        Color(red: 0.020, green: 0.588, blue: 0.412)  // #059669
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                    
                    // Sign Out button
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
                        .foregroundStyle(.primary)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    
                    // Delete Account button
                    Button(action: { showDeleteAccountConfirmation = true }) {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .frame(width: 28)
                            } else {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 18))
                                    .frame(width: 28)
                            }
                            
                            Text("Delete Account")
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
                    .disabled(isDeleting)
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
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteAccountConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    isDeleting = true
                    Task {
                        await authViewModel.deleteAccount()
                        await MainActor.run {
                            isDeleting = false
                            dismiss()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. Your account and all associated data (images, analysis results) will be permanently deleted.")
            }
            .sheet(isPresented: $showUpgradeSheet) {
                UpgradeAccountView()
            }
        }
    }
}

// MARK: - Upgrade Account View

struct UpgradeAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case email, password, confirmPassword, firstName, lastName
    }
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isUpgrading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.063, green: 0.725, blue: 0.506),
                                            Color(red: 0.020, green: 0.588, blue: 0.412)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white)
                        }
                        
                        Text("Upgrade Your Account")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Create login credentials to keep your images and unlock unlimited uploads.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Error message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                    
                    // Form fields
                    VStack(spacing: 16) {
                        // Name fields
                        HStack(spacing: 12) {
                            AuthTextField(
                                icon: "person.fill",
                                placeholder: "First Name",
                                text: $firstName
                            )
                            .focused($focusedField, equals: .firstName)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .lastName }
                            
                            AuthTextField(
                                icon: "person.fill",
                                placeholder: "Last Name",
                                text: $lastName
                            )
                            .focused($focusedField, equals: .lastName)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .email }
                        }
                        
                        AuthTextField(
                            icon: "envelope.fill",
                            placeholder: "Email",
                            text: $email,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress
                        )
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        
                        AuthSecureField(
                            icon: "lock.fill",
                            placeholder: "Password",
                            text: $password
                        )
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirmPassword }
                        
                        // Password requirements hint
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Password must contain:")
                                .font(.caption)
                                .foregroundStyle(Color.theme.textSecondary)
                            HStack(spacing: 16) {
                                PasswordRequirement(text: "8+ chars", met: password.count >= 8)
                                PasswordRequirement(text: "Uppercase", met: password.contains(where: { $0.isUppercase }))
                                PasswordRequirement(text: "Number", met: password.contains(where: { $0.isNumber }))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        
                        AuthSecureField(
                            icon: "lock.fill",
                            placeholder: "Confirm Password",
                            text: $confirmPassword
                        )
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.done)
                        .onSubmit { upgradeAccount() }
                        
                        // Password match indicator
                        if !confirmPassword.isEmpty {
                            HStack {
                                Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
                                Text(password == confirmPassword ? "Passwords match" : "Passwords don't match")
                            }
                            .font(.caption)
                            .foregroundStyle(password == confirmPassword ? .green : .red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Upgrade button
                    Button(action: upgradeAccount) {
                        HStack {
                            if isUpgrading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Upgrade Account")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.063, green: 0.725, blue: 0.506),
                                    Color(red: 0.020, green: 0.588, blue: 0.412)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color(red: 0.020, green: 0.588, blue: 0.412).opacity(0.4), radius: 15, x: 0, y: 8)
                    }
                    .disabled(isUpgrading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Spacer()
                }
            }
            .navigationTitle("Upgrade Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Account Upgraded!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your account has been upgraded. You now have unlimited uploads!")
            }
        }
    }
    
    private func upgradeAccount() {
        // Validation
        guard !firstName.isEmpty else {
            errorMessage = "Please enter your first name"
            return
        }
        guard !lastName.isEmpty else {
            errorMessage = "Please enter your last name"
            return
        }
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        guard !password.isEmpty else {
            errorMessage = "Please enter a password"
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        isUpgrading = true
        errorMessage = nil
        
        Task {
            do {
                try await authViewModel.upgradeGuestAccount(
                    email: email,
                    password: password,
                    givenName: firstName,
                    familyName: lastName
                )
                await MainActor.run {
                    isUpgrading = false
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isUpgrading = false
                }
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
                ImageDetailView(
                    analysisResult: analysisResult,
                    imageInfo: viewModel.getImageInfo(for: analysisResult.imageId),
                    uiImage: uiImage
                )
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
                // Solid green circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.063, green: 0.725, blue: 0.506), // #10B981
                                Color(red: 0.020, green: 0.588, blue: 0.412)  // #059669
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color(red: 0.020, green: 0.588, blue: 0.412).opacity(0.4), radius: 12, x: 0, y: 6) // #059669
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
}

#Preview {
    HomeView()
        .environment(ImageGridViewModel())
        .environment(AuthViewModel())
}
