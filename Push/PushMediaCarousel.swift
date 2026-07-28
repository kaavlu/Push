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
    /// Add yours action — no-op until contribution upload ships.
    var onAddYours: () -> Void = {}
    @State private var selectedIndex: Int = 0
    /// Drives auto-advance and the bottom play/pause control.
    @State private var isAutoPlaying: Bool = true
    /// True when this card is the primary on-screen push (not a peeking neighbor).
    @State private var isPrimarilyVisible: Bool = false
    /// 0…1 fill of the active progress segment (Stories-style timed load).
    @State private var segmentProgress: CGFloat = 0

    private var items: [FeedMediaItem] { data.items }
    private var cornerRadius: CGFloat { FeedMediaLayout.cornerRadius }
    private var showsProgressBar: Bool { items.count > 1 }
    /// Bottom interaction (avatars / play / Add yours) only on the first media slide.
    private var showsBottomChrome: Bool { selectedIndex == 0 }

    var body: some View {
        ZStack {
            mediaPages
            topChrome
            if showsBottomChrome {
                FeedMediaBottomInteraction(
                    participants: data.participants,
                    contributorName: data.contributorName,
                    canAddYours: data.canAddYours,
                    isPlaying: isAutoPlaying,
                    onTogglePlayback: {
                        isAutoPlaying.toggle()
                    },
                    onAddYours: onAddYours
                )
            }
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
        .background(visibilityProbe)
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
            segmentProgress = 0
        }
        .onChange(of: items.count) { count in
            selectedIndex = FeedMediaCarouselSelection.clampedIndex(selectedIndex, itemCount: count)
            segmentProgress = 0
        }
        // Restarts after each advance, swipe, play toggle, or visibility change.
        .task(id: autoAdvanceTaskID) {
            await runAutoAdvanceLoop()
        }
    }

    /// Bumps when identity, page, play, or on-screen primacy changes.
    private var autoAdvanceTaskID: String {
        "\(data.id)-\(items.count)-\(selectedIndex)-\(isAutoPlaying)-\(isPrimarilyVisible)"
    }

    @MainActor
    private func runAutoAdvanceLoop() async {
        guard items.count > 1 else {
            segmentProgress = 0
            return
        }
        // Paused or off-screen: freeze the active segment without advancing.
        guard isAutoPlaying, isPrimarilyVisible else { return }

        segmentProgress = 0
        let duration = FeedMediaLayout.autoAdvanceDuration
        let tickNanos = FeedMediaLayout.progressTickNanoseconds
        let start = Date()

        while !Task.isCancelled {
            let elapsed = Date().timeIntervalSince(start)
            let fraction = min(1, CGFloat(elapsed / duration))
            segmentProgress = fraction
            if fraction >= 1 { break }
            do {
                try await Task.sleep(nanoseconds: tickNanos)
            } catch {
                return
            }
            guard isAutoPlaying, isPrimarilyVisible else { return }
        }

        guard !Task.isCancelled, items.count > 1, isAutoPlaying, isPrimarilyVisible else { return }
        let next = (selectedIndex + 1) % items.count
        segmentProgress = 0
        withAnimation(.easeInOut(duration: FeedMediaLayout.autoAdvanceAnimationDuration)) {
            selectedIndex = next
        }
    }

    /// Tracks global frame so only the in-view card auto-advances.
    private var visibilityProbe: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            Color.clear
                .onAppear {
                    updatePrimaryVisibility(frame: frame)
                }
                .onChange(of: frame.minY) { _ in
                    updatePrimaryVisibility(frame: proxy.frame(in: .global))
                }
                .onChange(of: frame.height) { _ in
                    updatePrimaryVisibility(frame: proxy.frame(in: .global))
                }
        }
    }

    private func updatePrimaryVisibility(frame: CGRect) {
        let visible = FeedMediaVisibility.visibleScreenBounds()
        let next = FeedMediaVisibility.isPrimarilyVisible(
            frame: frame,
            in: visible,
            threshold: FeedMediaLayout.autoplayVisibilityThreshold
        )
        if next != isPrimarilyVisible {
            isPrimarilyVisible = next
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

    // MARK: - Top chrome (progress + location on every slide)

    private var topChrome: some View {
        ZStack(alignment: .top) {
            // Always soft-shade the top edge so progress segments stay readable on light media.
            FeedMediaTopScrim()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                if showsProgressBar {
                    FeedMediaProgressBar(
                        count: items.count,
                        selectedIndex: FeedMediaCarouselSelection.clampedIndex(
                            selectedIndex,
                            itemCount: items.count
                        ),
                        currentProgress: segmentProgress
                    )
                    .padding(.horizontal, FeedMediaLayout.progressHorizontalInset)
                    .padding(.top, FeedMediaLayout.progressTopInset)
                    .allowsHitTesting(false)
                }

                FeedMediaMetadataOverlay(
                    locationTitle: data.locationTitle,
                    onOverflowMenu: onOverflowMenu
                )
                .padding(.horizontal, FeedMediaLayout.metadataHorizontalInset)
                .padding(
                    .top,
                    showsProgressBar
                        ? FeedMediaLayout.progressToMetadataSpacing
                        : FeedMediaLayout.metadataTopInsetWithoutProgress
                )

                Spacer(minLength: 0)
            }
        }
    }

    private var accessibilitySummary: String {
        let count = items.count
        let locationBit = data.locationTitle.isEmpty ? "" : ", \(data.locationTitle)"
        if count == 0 {
            return "Media unavailable\(locationBit)"
        }
        let page = FeedMediaCarouselSelection.clampedIndex(selectedIndex, itemCount: count) + 1
        return "Media \(page) of \(count)\(locationBit)"
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
    let onOverflowMenu: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            FeedMediaLocationChip(locationTitle: locationTitle)
            Spacer(minLength: 8)
            FeedMediaOverflowButton(action: onOverflowMenu)
        }
    }
}

/// Compact single-row location pill — same height/radius family as the `…` control.
private struct FeedMediaLocationChip: View {
    let locationTitle: String

    var body: some View {
        Text(locationTitle)
            .font(FeedMediaMetadataStyle.locationFont)
            .foregroundStyle(FeedMediaMetadataStyle.textColor)
            .lineLimit(1)
            .minimumScaleFactor(PushOpacityTokens.minimumTextScale)
            .padding(.horizontal, FeedMediaMetadataStyle.chipHorizontalPadding)
            .frame(height: FeedMediaMetadataStyle.chipHeight)
            .fixedSize(horizontal: true, vertical: false)
            .pushMapControlGlass(
                cornerRadius: FeedMediaMetadataStyle.chipCornerRadius,
                treatment: .filterPill
            )
            .accessibilityLabel(locationTitle)
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
    /// 0…1 fill for the active segment (left → right load).
    var currentProgress: CGFloat = 0

    var body: some View {
        HStack(spacing: FeedMediaLayout.progressSpacing) {
            ForEach(0..<count, id: \.self) { index in
                FeedMediaProgressSegment(
                    fill: fillAmount(for: index)
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func fillAmount(for index: Int) -> CGFloat {
        if index < selectedIndex { return 1 }
        if index == selectedIndex { return min(1, max(0, currentProgress)) }
        return 0
    }
}

/// Track + growing fill — Stories-style timed segment.
private struct FeedMediaProgressSegment: View {
    let fill: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(
                        FeedMediaProgressStyle.segmentColor.opacity(
                            FeedMediaProgressStyle.remainingOpacity
                        )
                    )
                Capsule(style: .continuous)
                    .fill(
                        FeedMediaProgressStyle.segmentColor.opacity(
                            FeedMediaProgressStyle.currentOpacity
                        )
                    )
                    .frame(width: max(0, proxy.size.width * fill))
            }
        }
        .frame(height: FeedMediaLayout.progressHeight)
        .frame(maxWidth: .infinity)
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
