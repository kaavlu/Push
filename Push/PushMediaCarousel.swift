//
//  PushMediaCarousel.swift
//  Push
//
//  Reusable immersive media container for Feed Push cards (Issue #9 prompt 1).
//  Fixed portrait frame, fill-crop pages, manual paging, segmented progress.
//  No metadata, controls, or navigation chrome.
//

import SwiftUI
import UIKit

struct PushMediaCarousel: View {
    let data: FeedMediaCarouselData
    @Environment(\.pushLayout) private var layout
    @State private var selectedIndex: Int = 0

    private var items: [FeedMediaItem] { data.items }
    private var cornerRadius: CGFloat { FeedMediaLayout.cornerRadius(layout) }

    var body: some View {
        ZStack {
            mediaPages
            progressOverlay
        }
        .aspectRatio(FeedMediaLayout.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    PushColorPalette.Accent.walnut.opacity(FeedMediaLayout.mediaStrokeOpacity),
                    lineWidth: FeedMediaLayout.mediaStrokeWidth
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .onAppear {
            selectedIndex = FeedMediaCarouselSelection.clampedIndex(
                selectedIndex,
                itemCount: items.count
            )
        }
        .onChange(of: data.id) { _ in
            selectedIndex = 0
        }
        .onChange(of: items.count) { count in
            selectedIndex = FeedMediaCarouselSelection.clampedIndex(selectedIndex, itemCount: count)
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private var mediaPages: some View {
        if items.isEmpty {
            FeedMediaPlaceholderPage(kind: .missing)
        } else if items.count == 1, let only = items.first {
            // Avoid page TabView chrome/overhead for a single frame.
            FeedMediaPageView(item: only)
        } else {
            TabView(selection: $selectedIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    FeedMediaPageView(item: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressOverlay: some View {
        // Empty media still shows one subdued segment over the missing placeholder.
        let count = max(items.count, 1)
        VStack {
            FeedMediaProgressBar(
                count: count,
                selectedIndex: FeedMediaCarouselSelection.clampedIndex(
                    selectedIndex,
                    itemCount: count
                )
            )
            .padding(.horizontal, FeedMediaLayout.progressHorizontalInset)
            .padding(.top, FeedMediaLayout.progressTopInset)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }

    private var accessibilitySummary: String {
        let count = items.count
        if count == 0 {
            return "Media unavailable"
        }
        let page = FeedMediaCarouselSelection.clampedIndex(selectedIndex, itemCount: count) + 1
        return "Media \(page) of \(count)"
    }
}

// MARK: - Progress bar

struct FeedMediaProgressBar: View {
    let count: Int
    let selectedIndex: Int

    var body: some View {
        HStack(spacing: FeedMediaLayout.progressSpacing) {
            ForEach(0..<count, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(FeedMediaProgressStyle.segmentColor.opacity(opacity(for: index)))
                    .frame(height: FeedMediaLayout.progressHeight)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func opacity(for index: Int) -> Double {
        if index < selectedIndex {
            return FeedMediaProgressStyle.completedOpacity
        }
        if index == selectedIndex {
            return FeedMediaProgressStyle.currentOpacity
        }
        return FeedMediaProgressStyle.remainingOpacity
    }
}

// MARK: - Page

private struct FeedMediaPageView: View {
    let item: FeedMediaItem

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                FeedMediaPlaceholderStyle.background
                pageContent(size: size)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    @ViewBuilder
    private func pageContent(size: CGSize) -> some View {
        switch item.source {
        case .loading:
            FeedMediaPlaceholderPage(kind: .loading)
        case .missing:
            FeedMediaPlaceholderPage(kind: .missing)
        case .assetPath(let path):
            FeedMediaResolvedImage(path: path, size: size)
        case .solidColor(let swatch):
            fillImage(FeedMediaImageFactory.image(for: swatch), size: size)
        }
    }

    private func fillImage(_ image: UIImage, size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}

// MARK: - Resolved asset image

private struct FeedMediaResolvedImage: View {
    let path: String
    let size: CGSize
    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else if didFail {
                FeedMediaPlaceholderPage(kind: .missing)
            } else {
                FeedMediaPlaceholderPage(kind: .loading)
            }
        }
        .task(id: path) {
            await resolve()
        }
    }

    @MainActor
    private func resolve() async {
        if let local = AvatarImageLoader.localImage(for: path) {
            image = local
            didFail = false
            return
        }
        if let remote = await AvatarImageLoader.image(for: path) {
            image = remote
            didFail = false
        } else {
            image = nil
            didFail = true
        }
    }
}

// MARK: - Placeholder

private enum FeedMediaPlaceholderKind {
    case loading
    case missing
}

private struct FeedMediaPlaceholderPage: View {
    let kind: FeedMediaPlaceholderKind

    var body: some View {
        ZStack {
            FeedMediaPlaceholderStyle.background
            VStack(spacing: FeedMediaLayout.placeholderStackSpacing) {
                switch kind {
                case .loading:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(FeedMediaPlaceholderStyle.spinnerTint)
                        .scaleEffect(1.1)
                    Text("Loading media")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(FeedMediaPlaceholderStyle.captionColor)
                case .missing:
                    Image(systemName: "photo")
                        .font(.system(size: FeedMediaLayout.placeholderIconSize, weight: .medium))
                        .foregroundStyle(FeedMediaPlaceholderStyle.iconColor)
                        .symbolRenderingMode(.hierarchical)
                    Text("No media yet")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(FeedMediaPlaceholderStyle.captionColor)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(kind == .loading ? "Loading media" : "No media yet")
    }
}

// MARK: - Previews

#if DEBUG
struct PushMediaCarousel_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            ScrollView {
                VStack(spacing: 16) {
                    previewBlock(title: "Three mixed aspect ratios", data: .threeMixedAspectPhotos)
                    previewBlock(title: "Three bundle photos", data: .threeBundlePhotos)
                    previewBlock(title: "Single photo", data: .singlePhoto)
                    previewBlock(title: "Mixed shapes + asset", data: .mixedPortraitLandscapeSquare)
                    previewBlock(title: "Loading", data: .loadingMedia)
                    previewBlock(title: "Missing", data: .missingMedia)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(PushIvoryPageBackground())
        }
    }

    private static func previewBlock(title: String, data: FeedMediaCarouselData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
            PushMediaCarousel(data: data)
        }
    }
}

private extension FeedMediaCarouselData {
    static let threeMixedAspectPhotos = FeedMediaCarouselFixtures.threeMixedAspectPhotos
    static let threeBundlePhotos = FeedMediaCarouselFixtures.threeBundlePhotos
    static let singlePhoto = FeedMediaCarouselFixtures.singlePhoto
    static let mixedPortraitLandscapeSquare = FeedMediaCarouselFixtures.mixedPortraitLandscapeSquare
    static let loadingMedia = FeedMediaCarouselFixtures.loadingMedia
    static let missingMedia = FeedMediaCarouselFixtures.missingMedia
}
#endif
