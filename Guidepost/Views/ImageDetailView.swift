//
//  ImageDetailView.swift
//  Guidepost
//
//  Created by John Gambrell on 11/21/25.
//

import SwiftUI

struct ImageDetailView: View {
    let analysisResult: ImageAnalysisResult
    let uiImage: UIImage?

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var metadataHeight: CGFloat = 240

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black
                    .ignoresSafeArea()

                // Image layer - aligned to top
                if let uiImage = uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(maxWidth: .infinity)
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

                // Metadata overlay - positioned at bottom
                VStack {
                    Spacer()
                    MetadataOverlay(analysisResult: analysisResult, height: $metadataHeight, maxHeight: geometry.size.height * 0.8)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Metadata Overlay

struct MetadataOverlay: View {
    let analysisResult: ImageAnalysisResult
    @Binding var height: CGFloat
    let maxHeight: CGFloat

    @State private var dragOffset: CGFloat = 0

    private let minHeight: CGFloat = 120
    private var mediumHeight: CGFloat { maxHeight * 0.4 }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.gray)
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Analysis Status
                    if analysisResult.status != .completed {
                        HStack {
                            Image(systemName: analysisResult.status == .failed ? "exclamationmark.triangle.fill" : "clock.fill")
                                .foregroundColor(analysisResult.status == .failed ? .red : .orange)
                            Text(analysisResult.status.rawValue.capitalized)
                                .font(.headline)
                                .foregroundColor(analysisResult.status == .failed ? .red : .orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            (analysisResult.status == .failed ? Color.red : Color.orange)
                                .opacity(0.1)
                        )
                        .cornerRadius(8)

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
                                        .foregroundColor(.blue)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }

                   
                   
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .frame(height: height + dragOffset)
        .frame(maxWidth: .infinity)
        .background(
            Color(.systemBackground)
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: -5)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = -value.translation.height
                }
                .onEnded { value in
                    withAnimation(.spring()) {
                        let newHeight = height + dragOffset

                        if newHeight < (minHeight + mediumHeight) / 2 {
                            height = minHeight
                        } else if newHeight < (mediumHeight + maxHeight) / 2 {
                            height = mediumHeight
                        } else {
                            height = maxHeight
                        }

                        dragOffset = 0
                    }
                }
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
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
