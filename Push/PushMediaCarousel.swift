//
//  PushMediaCarousel.swift
//  Push
//
//  Feed media card: cinematic media stack (progress, participants; tap media to
//  pause/play auto-advance) plus cream content band (title, meta, + / …).
//

import SwiftUI
import UIKit

struct PushMediaCarousel: View {
    let data: FeedMediaCarouselData
    /// Participant-only: opens edit moment (Create Post compose for this card).
    var onOverflowMenu: () -> Void = {}
    /// Participant-only: opens the Add Yours contribution flow.
    var onAddYours: () -> Void = {}
    @State private var selectedIndex: Int = 0
    /// Drives auto-advance; toggled by tapping the current media page.
    @State private var isAutoPlaying: Bool = true
    /// True when this card is the primary on-screen push (not a peeking neighbor).
    @State private var isPrimarilyVisible: Bool = false
    /// 0…1 fill of the active progress segment (Stories-style timed load).
    @State private var segmentProgress: CGFloat = 0

    private var items: [FeedMediaItem] { data.items }
    private var cornerRadius: CGFloat { FeedMediaLayout.cardCornerRadius }
    private var showsProgressBar: Bool { items.count > 1 }
    /// Multi-page: chrome rides on slide 0 inside the strip. Single: overlay on media.
    private var showsStandaloneBottomChrome: Bool { items.count <= 1 }

    var body: some View {
        VStack(spacing: 0) {
            mediaSurface
            FeedMediaCardContentSection(
                title: data.title,
                metaLine: data.locationDateMetaLine,
                canAddYours: data.canAddYours,
                onOverflowMenu: onOverflowMenu,
                onAddYours: onAddYours
            )
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    PushColorPalette.Accent.walnut.opacity(PushCreamTokens.solidCardStrokeOpacity),
                    lineWidth: PushCreamTokens.solidCardStrokeWidth
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
            segmentProgress = 0
        }
        .onChange(of: items.count) { count in
            selectedIndex = FeedMediaCarouselSelection.clampedIndex(selectedIndex, itemCount: count)
            segmentProgress = 0
        }
        // New page (swipe or auto-advance) always starts its segment empty.
        .onChange(of: selectedIndex) { _ in
            segmentProgress = 0
        }
        // Restarts after advance, swipe, play toggle, or visibility change.
        // Pause freezes fill; resume continues from `segmentProgress` (not zero).
        .task(id: autoAdvanceTaskID) {
            await runAutoAdvanceLoop()
        }
    }

    /// Media frame only — progress + first-slide participants.
    private var mediaSurface: some View {
        ZStack {
            mediaPages
            topChrome
            if showsStandaloneBottomChrome {
                bottomChrome
            }
        }
        .aspectRatio(FeedMediaLayout.aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(FeedMediaPlaceholderStyle.background)
        .background(visibilityProbe)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isAutoPlaying ? "Double tap to pause" : "Double tap to play")
        .accessibilityAction {
            toggleAutoplay()
        }
    }

    private func toggleAutoplay() {
        // Auto-advance only applies to multi-item stacks; still toggle so a11y
        // state stays consistent if items are added later in-session.
        isAutoPlaying.toggle()
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

        let duration = FeedMediaLayout.autoAdvanceDuration
        let tickNanos = FeedMediaLayout.progressTickNanoseconds
        // Resume from frozen fill (tap-to-pause); new slides reset via onChange(selectedIndex).
        let startProgress = min(1, max(0, segmentProgress))
        let start = Date().addingTimeInterval(-duration * Double(startProgress))

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

        // Hold the active segment at full fill, then advance so it becomes a
        // completed segment (stays full until the loop returns to slide 0).
        // Never zero progress while this index is still selected — that flashes empty.
        segmentProgress = 1
        let next = (selectedIndex + 1) % items.count
        // Strip owns page swipe animation (including last → first via a clone page).
        // onChange(selectedIndex) clears progress for the next segment.
        var handoff = Transaction()
        handoff.disablesAnimations = true
        withTransaction(handoff) {
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
                        .onTapGesture(perform: toggleAutoplay)
                } else if items.count == 1, let only = items.first {
                    FeedMediaPageView(item: only, size: size)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: toggleAutoplay)
                } else {
                    FeedMediaPageStrip(
                        items: items,
                        selectedIndex: $selectedIndex,
                        size: size,
                        onMediaTap: toggleAutoplay,
                        firstPageChrome: { bottomChrome }
                    )
                    .frame(width: size.width, height: size.height)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    private var bottomChrome: some View {
        FeedMediaBottomInteraction(
            participants: data.participants,
            contributorName: data.contributorName
        )
    }

    // MARK: - Top chrome (progress only — title / location / overflow live below media)

    private var topChrome: some View {
        ZStack(alignment: .top) {
            // Soft-shade the top edge so progress segments stay readable on light media.
            FeedMediaTopScrim()
                .allowsHitTesting(false)

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
        }
    }

    private var accessibilitySummary: String {
        let titleBit = data.title.isEmpty ? "" : data.title
        let metaBit = data.locationDateMetaLine.isEmpty ? "" : ", \(data.locationDateMetaLine)"
        let count = items.count
        if count == 0 {
            return [titleBit, "Media unavailable\(metaBit)"]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
        let page = FeedMediaCarouselSelection.clampedIndex(selectedIndex, itemCount: count) + 1
        let mediaBit = "Media \(page) of \(count)\(metaBit)"
        return titleBit.isEmpty ? mediaBit : "\(titleBit), \(mediaBit)"
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
        FeedMediaProgressFill.amount(
            for: index,
            selectedIndex: selectedIndex,
            currentProgress: currentProgress
        )
    }
}

/// Pure fill rules for Stories-style segments (testable).
enum FeedMediaProgressFill {
    /// Completed segments stay full until the carousel loops back to index 0.
    static func amount(
        for index: Int,
        selectedIndex: Int,
        currentProgress: CGFloat
    ) -> CGFloat {
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
        // Avoid implicit animations rewinding a completed segment to empty.
        .transaction { $0.animation = nil }
    }
}

// MARK: - Page

struct FeedMediaPageView: View {
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
