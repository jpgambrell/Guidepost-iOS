//
//  ImageDetailView.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import SwiftUI

struct ImageDetailView: View {
    @State private var analysisResult: ImageAnalysisResult
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

    init(analysisResult: ImageAnalysisResult, uiImage: UIImage?) {
        self._analysisResult = State(initialValue: analysisResult)
        self.uiImage = uiImage
    }

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let sheetMaxHeight = screenHeight * 0.7
            
            ZStack(alignment: .bottom) {
                // Background
                Color.black.ignoresSafeArea()

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
            
            Divider()
            
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
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundStyle(.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }
                    }
                }
                .padding()
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
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
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
