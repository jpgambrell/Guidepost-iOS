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

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showMetadata = true
    @State private var isRefreshing = false

    init(analysisResult: ImageAnalysisResult, uiImage: UIImage?) {
        self._analysisResult = State(initialValue: analysisResult)
        self.uiImage = uiImage
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            // Image layer - aligned to top
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
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
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMetadata) {
            MetadataSheetView(
                analysisResult: analysisResult,
                onRefresh: { await fetchLatestAnalysis() }
            )
            .presentationDetents(
                [.height(60), .height(200), .large], selection: .constant(.height(200))
            )
            .presentationBackgroundInteraction(.enabled)
            .presentationBackground(.thinMaterial)
            .presentationCornerRadius(16)
            .interactiveDismissDisabled()
        }
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

// MARK: - Metadata Sheet

struct MetadataSheetView: View {
    let analysisResult: ImageAnalysisResult
    let onRefresh: () async -> Void

    var body: some View {
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
