//
//  ImageDetailView.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import CoreLocation
import MapKit
import SwiftUI

struct ImageDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var analysisResult: ImageAnalysisResult
    let imageInfo: ImageInfo?  // Passed in from HomeView (no fetch needed)
    let uiImage: UIImage?

    // Zoom/pan state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Sheet state
    @State private var sheetOffset: CGFloat = 0
    @State private var isSheetOpen = false
    @State private var isRefreshing = false
    
    // Image scale based on sheet position (TikTok-style)
    private let minImageScale: CGFloat = 0.55
    
    private func imageScale(for screenHeight: CGFloat) -> CGFloat {
        let sheetMaxHeight = screenHeight * 0.7
        guard sheetMaxHeight > 0 else { return 1 }
        let progress = sheetOffset / sheetMaxHeight
        return 1 - (progress * (1 - minImageScale))
    }
    
    // Move image up as sheet rises
    private func imageOffsetY(for screenHeight: CGFloat) -> CGFloat {
        let sheetMaxHeight = screenHeight * 0.7
        guard sheetMaxHeight > 0 else { return 0 }
        let progress = sheetOffset / sheetMaxHeight
        return -progress * (screenHeight * 0.25)
    }

    init(analysisResult: ImageAnalysisResult, imageInfo: ImageInfo?, uiImage: UIImage?) {
        self._analysisResult = State(initialValue: analysisResult)
        self.imageInfo = imageInfo
        self.uiImage = uiImage
    }

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let sheetMaxHeight = screenHeight * 0.7
            
            ZStack(alignment: .bottom) {
                // Background - adapts to light/dark mode
                (colorScheme == .dark ? Color.black : Color.white).ignoresSafeArea()

                // Image layer with TikTok-style scaling
                if let uiImage = uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(isSheetOpen ? imageScale(for: screenHeight) : scale)
                        .offset(y: isSheetOpen ? imageOffsetY(for: screenHeight) : offset.height)
                        .offset(x: isSheetOpen ? 0 : offset.width)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: isSheetOpen ? 12 : 0))
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isSheetOpen)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    guard !isSheetOpen else { return }
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 5)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1 {
                                        withAnimation(.spring()) {
                                            scale = 1
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    guard !isSheetOpen else { return }
                                    if scale > 1 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    .onTapGesture(count: 2) {
                        guard !isSheetOpen else { return }
                        withAnimation(.spring()) {
                            if scale > 1 {
                                scale = 1
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2
                            }
                        }
                    }
                    .onTapGesture(count: 1) {
                        if isSheetOpen {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                isSheetOpen = false
                                sheetOffset = 0
                            }
                        }
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Metadata sheet (TikTok-style)
                MetadataSheet(
                    offset: $sheetOffset,
                    isOpen: $isSheetOpen,
                    maxHeight: sheetMaxHeight,
                    analysisResult: analysisResult,
                    imageInfo: imageInfo,
                    onRefresh: { await fetchLatestAnalysis() }
                )
            }
            .onAppear {
                // Auto-open sheet on view load
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isSheetOpen = true
                        sheetOffset = sheetMaxHeight
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchLatestAnalysis()
        }
    }

    private func fetchLatestAnalysis() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let updatedResult = try await ImageAPIService.shared.fetchAnalysis(
                imageId: analysisResult.imageId)
            analysisResult = updatedResult
        } catch {
            print("Failed to fetch latest analysis: \(error)")
        }
    }
}

// MARK: - Metadata Sheet (TikTok-style)

struct MetadataSheet: View {
    @Binding var offset: CGFloat
    @Binding var isOpen: Bool
    let maxHeight: CGFloat
    let analysisResult: ImageAnalysisResult
    let imageInfo: ImageInfo?
    let onRefresh: () async -> Void
    
    // Collapsed state shows just the handle for easy grabbing
    private let collapsedHeight: CGFloat = 70
    private let handleAreaHeight: CGFloat = 50
    
    private var sheetPosition: CGFloat {
        if isOpen {
            return 0
        } else {
            // When collapsed, show just the handle area peeking up
            return maxHeight - collapsedHeight
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle area - larger hit target with more padding
            dragHandle
            
            //Divider()
            
            // Metadata content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Analysis Status
                    if analysisResult.status != .completed {
                        HStack {
                            Image(
                                systemName: analysisResult.status == .failed
                                    ? "exclamationmark.triangle.fill" : "clock.fill"
                            )
                            .foregroundStyle(analysisResult.status == .failed ? .red : .orange)
                            Text(analysisResult.status.rawValue.capitalized)
                                .font(.headline)
                                .foregroundStyle(analysisResult.status == .failed ? .red : .orange)
                            Button("Refresh") {
                                Task {
                                    await onRefresh()
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            (analysisResult.status == .failed ? Color.red : Color.orange)
                                .opacity(0.1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        if let error = analysisResult.error {
                            MetadataRow(title: "Error", value: error)
                        }
                    }

                    // Description
                    if let description = analysisResult.description {
                        MetadataRow(title: "Description", value: description)
                    }

                    // Keywords
                    if let keywords = analysisResult.keywords, !keywords.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Keywords")
                                .font(.headline)
                            FlowLayout(spacing: 8) {
                                ForEach(keywords, id: \.self) { keyword in
                                    Text(keyword)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(red: 0.063, green: 0.725, blue: 0.506).opacity(0.2)) // #10B981
                                        .foregroundStyle(Color(red: 0.020, green: 0.588, blue: 0.412)) // #059669
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
                    }
                    
                    // Location & Date Section (from image info)
                    if let info = imageInfo, (info.hasLocation || info.creationDate != nil) {
                        VStack(alignment: .leading, spacing: 12) {
                            // Creation Date
                            if let dateString = info.formattedCreationDate {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(.orange)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Taken")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(dateString)
                                            .font(.subheadline)
                                    }
                                }
                            }
                            
                            // Location Map Thumbnail
                            if let lat = info.latitude, let lon = info.longitude {
                                LocationMapThumbnail(latitude: lat, longitude: lon)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(height: maxHeight)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 10, y: -5)
        )
        .offset(y: sheetPosition)
    }
    
    private var dragHandle: some View {
        Rectangle()
            .fill(Color(.systemBackground))
            .frame(height: handleAreaHeight)
            .overlay(
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 5)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        let threshold: CGFloat = 50
                        
                        if isOpen {
                            // Currently open - check if should close
                            if value.translation.height > threshold || velocity > 300 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    isOpen = false
                                    offset = 0
                                }
                            }
                        } else {
                            // Currently collapsed - check if should open
                            if value.translation.height < -threshold || velocity < -300 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    isOpen = true
                                    offset = maxHeight
                                }
                            }
                        }
                    }
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isOpen)
    }
}

// MARK: - Metadata Row

struct MetadataRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.body)
        }
    }
}

// MARK: - Location Map Thumbnail

struct LocationMapThumbnail: View {
    let latitude: Double
    let longitude: Double
    
    @State private var addressText: String?
    @State private var resolvedMapItem: MKMapItem?
    
    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Address text
            if let address = addressText {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Color(red: 0.063, green: 0.725, blue: 0.506))
                        .font(.title3)
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // Map thumbnail
            Button(action: openInAppleMaps) {
                ZStack(alignment: .bottomLeading) {
                    Map(initialPosition: .region(region)) {
                        Marker("", coordinate: coordinate)
                            .tint(.red)
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .allowsHitTesting(false)
                    
                    // "Open in Maps" label overlay
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption2)
                        Text("Open in Maps")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Capsule())
                    .padding(8)
                }
            }
            .buttonStyle(.plain)
        }
        .task {
            await reverseGeocode()
        }
    }
    
    private func reverseGeocode() async {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        guard let request = MKReverseGeocodingRequest(location: location) else {
            // Fallback to coordinates if request creation fails
            addressText = String(format: "%.4f, %.4f", latitude, longitude)
            return
        }
        
        do {
            let mapItems = try await request.mapItems
            if let mapItem = mapItems.first {
                resolvedMapItem = mapItem
                addressText = formatAddress(from: mapItem)
            } else {
                addressText = String(format: "%.4f, %.4f", latitude, longitude)
            }
        } catch {
            print("Reverse geocoding failed: \(error.localizedDescription)")
            // Fallback to coordinates if geocoding fails
            addressText = String(format: "%.4f, %.4f", latitude, longitude)
        }
    }
    
    private func formatAddress(from mapItem: MKMapItem) -> String {
        var components: [String] = []
        
        // Use the map item's name if it's a point of interest
        if let name = mapItem.name, !name.isEmpty {
            // Check if name is different from short address
            let shortAddr = mapItem.address?.shortAddress ?? ""
            if name != shortAddr && !shortAddr.contains(name) {
                components.append(name)
            }
        }
        
        // Use shortAddress from MKAddress
        if let address = mapItem.address, let shortAddr = address.shortAddress, !shortAddr.isEmpty {
            // If we already have a POI name, skip adding duplicate short address
            if components.isEmpty || !shortAddr.contains(components[0]) {
                components.append(shortAddr)
            }
        }
        
        if components.isEmpty {
            return String(format: "%.4f, %.4f", latitude, longitude)
        }
        
        return components.joined(separator: "\n")
    }
    
    private func openInAppleMaps() {
        let mapItem: MKMapItem
        
        if let resolved = resolvedMapItem {
            mapItem = resolved
        } else {
            // Fallback: create map item with just location
            mapItem = MKMapItem(location: CLLocation(latitude: latitude, longitude: longitude), address: nil)
            mapItem.name = "Photo Location"
        }
        
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue
        ])
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews,
            spacing: spacing)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
