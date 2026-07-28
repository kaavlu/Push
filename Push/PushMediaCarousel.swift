//
//  PushMediaCarousel.swift
//  Push
//
//  Compact cinematic media container for Feed Push cards.
//  Fixed portrait frame, fill-crop pages, manual + auto paging, segmented progress,
//  and top metadata overlay (location, date/time, overflow).
//

import SwiftUI
import UIKit

struct PushMediaCarousel: View {
    let data: FeedMediaCarouselData
    /// Overflow menu action — no-op until card chrome menus ship.
    var onOverflowMenu: () -> Void = {}
    @State private var selectedIndex: Int = 0

    private var items: [FeedMediaItem] { data.items }
    private var cornerRadius: CGFloat { FeedMediaLayout.cornerRadius }
    private var showsProgressBar: Bool { items.count > 1 }

    var body: some View {
        ZStack {
            mediaPages
            topChrome
        }
        .aspectRatio(FeedMediaLayout.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(FeedMediaPlaceholderStyle.background)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    PushColorPalette.Accent.walnut.opacity(FeedMediaLayout.mediaStrokeOpacity),
                    lineWidth: FeedMediaLayout.mediaStrokeWidth
                )
        }
        // Flatten paging layers so neighbors never bleed past the rounded mask at rest.
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
        // Restarts after each advance and after manual swipe so dwell time stays consistent.
        .task(id: autoAdvanceTaskID) {
            await runAutoAdvanceLoop()
        }
    }

    /// Bumps when the carousel identity or page count changes so autoplay resets cleanly.
    private var autoAdvanceTaskID: String {
        "\(data.id)-\(items.count)-\(selectedIndex)"
    }

    @MainActor
    private func runAutoAdvanceLoop() async {
        guard items.count > 1 else { return }
        let nanos = UInt64(FeedMediaLayout.autoAdvanceDuration * 1_000_000_000)
        do {
            try await Task.sleep(nanoseconds: nanos)
        } catch {
            return
        }
        guard !Task.isCancelled, items.count > 1 else { return }
        let next = (selectedIndex + 1) % items.count
        withAnimation(.easeInOut(duration: FeedMediaLayout.autoAdvanceAnimationDuration)) {
            selectedIndex = next
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private var mediaPages: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Group {
                if items.isEmpty {
                    FeedMediaPlaceholderPage(kind: .missing)
                } else if items.count == 1, let only = items.first {
                    FeedMediaPageView(item: only, size: size)
                } else {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            FeedMediaPageView(item: item, size: size)
                                .frame(width: size.width, height: size.height)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(width: size.width, height: size.height)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    // MARK: - Top chrome (scrim + progress + metadata)

    private var topChrome: some View {
        ZStack(alignment: .top) {
            FeedMediaTopScrim()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                if showsProgressBar {
                    FeedMediaProgressBar(
                        count: items.count,
                        selectedIndex: FeedMediaCarouselSelection.clampedIndex(
                            selectedIndex,
                            itemCount: items.count
                        )
                    )
                    .padding(.horizontal, FeedMediaLayout.progressHorizontalInset)
                    .padding(.top, FeedMediaLayout.progressTopInset)
                    .allowsHitTesting(false)

                    FeedMediaMetadataOverlay(
                        locationTitle: data.locationTitle,
                        dateTimeLabel: data.dateTimeLabel,
                        onOverflowMenu: onOverflowMenu
                    )
                    .padding(.horizontal, FeedMediaLayout.metadataHorizontalInset)
                    .padding(.top, FeedMediaLayout.progressToMetadataSpacing)
                } else {
                    FeedMediaMetadataOverlay(
                        locationTitle: data.locationTitle,
                        dateTimeLabel: data.dateTimeLabel,
                        onOverflowMenu: onOverflowMenu
                    )
                    .padding(.horizontal, FeedMediaLayout.metadataHorizontalInset)
                    .padding(.top, FeedMediaLayout.metadataTopInsetWithoutProgress)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var accessibilitySummary: String {
        let count = items.count
        let locationBit = data.locationTitle.isEmpty ? "" : ", \(data.locationTitle)"
        let whenBit = data.dateTimeLabel.isEmpty ? "" : ", \(data.dateTimeLabel)"
        if count == 0 {
            return "Media unavailable\(locationBit)\(whenBit)"
        }
        let page = FeedMediaCarouselSelection.clampedIndex(selectedIndex, itemCount: count) + 1
        return "Media \(page) of \(count)\(locationBit)\(whenBit)"
    }
}

// MARK: - Top scrim

private struct FeedMediaTopScrim: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(
                        color: Color.black.opacity(FeedMediaMetadataStyle.scrimTopOpacity),
                        location: 0
                    ),
                    .init(
                        color: Color.black.opacity(FeedMediaMetadataStyle.scrimMidOpacity),
                        location: FeedMediaMetadataStyle.scrimMidStop
                    ),
                    .init(color: Color.clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: FeedMediaLayout.metadataScrimHeight)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Metadata overlay

private struct FeedMediaMetadataOverlay: View {
    let locationTitle: String
    let dateTimeLabel: String
    let onOverflowMenu: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            FeedMediaLocationTimeChip(
                locationTitle: locationTitle,
                dateTimeLabel: dateTimeLabel
            )
            Spacer(minLength: 8)
            FeedMediaOverflowButton(action: onOverflowMenu)
        }
    }
}

/// Single liquid-glass chip for location + time — map filter-pill family (DS-011).
private struct FeedMediaLocationTimeChip: View {
    let locationTitle: String
    let dateTimeLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: FeedMediaLayout.metadataTextStackSpacing) {
            Text(locationTitle)
                .font(FeedMediaMetadataStyle.locationFont)
                .foregroundStyle(FeedMediaMetadataStyle.textColor)
                .lineLimit(1)
                .minimumScaleFactor(PushOpacityTokens.minimumTextScale)
            Text(dateTimeLabel)
                .font(FeedMediaMetadataStyle.dateTimeFont)
                .foregroundStyle(
                    FeedMediaMetadataStyle.textColor.opacity(FeedMediaMetadataStyle.dateTimeOpacity)
                )
                .lineLimit(1)
                .minimumScaleFactor(PushOpacityTokens.minimumTextScale)
        }
        .padding(.horizontal, FeedMediaMetadataStyle.chipHorizontalPadding)
        .padding(.vertical, FeedMediaMetadataStyle.chipVerticalPadding)
        .fixedSize(horizontal: true, vertical: true)
        .pushMapControlGlass(
            cornerRadius: FeedMediaMetadataStyle.chipCornerRadius,
            treatment: .filterPill
        )
        .accessibilityElement(children: .combine)
    }
}

/// Map profile-style liquid glass circle — same `pushMapControlGlass(.profileButton)` as
/// `TopIconButton` on the live map (DS-011), not cream `PushCircleIconButton`.
private struct FeedMediaOverflowButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "ellipsis")
                .font(.system(
                    size: FeedMediaMetadataStyle.overflowIconSize,
                    weight: FeedMediaMetadataStyle.overflowIconWeight
                ))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(
                    width: FeedMediaMetadataStyle.overflowButtonSize,
                    height: FeedMediaMetadataStyle.overflowButtonSize
                )
                .pushMapControlGlass(
                    cornerRadius: FeedMediaMetadataStyle.overflowCornerRadius,
                    treatment: .profileButton
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More options")
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
    let size: CGSize

    var body: some View {
        ZStack {
            FeedMediaPlaceholderStyle.background
            pageContent
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private var pageContent: some View {
        switch item.source {
        case .loading:
            FeedMediaPlaceholderPage(kind: .loading)
        case .missing:
            FeedMediaPlaceholderPage(kind: .missing)
        case .assetPath(let path):
            FeedMediaResolvedImage(path: path, size: size)
        case .solidColor(let swatch):
            fillImage(FeedMediaImageFactory.image(for: swatch))
        }
    }

    private func fillImage(_ image: UIImage) -> some View {
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
        .frame(width: size.width, height: size.height)
        .clipped()
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
                VStack(spacing: FeedLayout.mediaStackSpacing) {
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
