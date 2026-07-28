//
//  FeedMediaModels.swift
//  Push
//
//  Presentation models + fixtures for the Feed media carousel foundation
//  (Issue #9, prompt 1). Isolated from seed/repos — no backend wiring.
//

import CoreGraphics
import Foundation
import UIKit

// MARK: - Models

enum FeedMediaKind: String, Equatable {
    case photo
    /// Poster still only — playback is out of scope for this step.
    case video
}

/// How a single carousel page should render.
enum FeedMediaSource: Equatable {
    /// Bundle / local path resolved via `AvatarImageLoader` / `PushImageAssets`.
    case assetPath(String)
    /// Programmatic solid fill used to demo aspect-ratio cropping without new assets.
    case solidColor(FeedSolidMediaSwatch)
    case loading
    case missing
}

struct FeedSolidMediaSwatch: Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    /// Source pixel size — different ratios prove fill-crop stays frame-stable.
    let width: CGFloat
    let height: CGFloat

    var size: CGSize { CGSize(width: width, height: height) }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

struct FeedMediaItem: Identifiable, Equatable {
    let id: String
    let kind: FeedMediaKind
    let source: FeedMediaSource
}

/// One immersive media stack that will later sit under full Push-card chrome.
struct FeedMediaCarouselData: Identifiable, Equatable {
    let id: String
    let items: [FeedMediaItem]
    /// Upper-left venue / location line (presentation-ready).
    let locationTitle: String
    /// Date + time under location (presentation-ready).
    let dateTimeLabel: String

    var isEmpty: Bool { items.isEmpty }
}

// MARK: - Selection helper

enum FeedMediaCarouselSelection {
    /// Keeps page index valid when item count changes (including empty → 0).
    static func clampedIndex(_ index: Int, itemCount: Int) -> Int {
        guard itemCount > 0 else { return 0 }
        return min(max(0, index), itemCount - 1)
    }
}

// MARK: - Fixtures

enum FeedMediaCarouselFixtures {
    /// Warm solid swatches with distinct source aspect ratios.
    private static let portraitSwatch = FeedSolidMediaSwatch(
        red: 0.55, green: 0.38, blue: 0.22,
        width: 900, height: 1400
    )
    private static let landscapeSwatch = FeedSolidMediaSwatch(
        red: 0.35, green: 0.48, blue: 0.42,
        width: 1600, height: 900
    )
    private static let squareSwatch = FeedSolidMediaSwatch(
        red: 0.72, green: 0.55, blue: 0.28,
        width: 1000, height: 1000
    )
    private static let tallPortraitSwatch = FeedSolidMediaSwatch(
        red: 0.42, green: 0.28, blue: 0.38,
        width: 800, height: 1600
    )

    /// Three photos with different source aspect ratios (portrait / landscape / square).
    static let threeMixedAspectPhotos = FeedMediaCarouselData(
        id: "fixture-three-mixed",
        items: [
            FeedMediaItem(id: "mixed-0", kind: .photo, source: .solidColor(portraitSwatch)),
            FeedMediaItem(id: "mixed-1", kind: .photo, source: .solidColor(landscapeSwatch)),
            FeedMediaItem(id: "mixed-2", kind: .photo, source: .solidColor(squareSwatch)),
        ],
        locationTitle: "Dolores Park",
        dateTimeLabel: "Sat · 4:30 PM"
    )

    /// Single photo carousel.
    static let singlePhoto = FeedMediaCarouselData(
        id: "fixture-single",
        items: [
            FeedMediaItem(
                id: "single-0",
                kind: .photo,
                source: .assetPath("assets/friends/pranay.png")
            ),
        ],
        locationTitle: "Home",
        dateTimeLabel: "Tonight · 8:00 PM"
    )

    /// Mixed portrait, landscape, square solids plus a real portrait asset.
    static let mixedPortraitLandscapeSquare = FeedMediaCarouselData(
        id: "fixture-mixed-shapes",
        items: [
            FeedMediaItem(id: "shape-0", kind: .photo, source: .solidColor(tallPortraitSwatch)),
            FeedMediaItem(id: "shape-1", kind: .photo, source: .solidColor(landscapeSwatch)),
            FeedMediaItem(id: "shape-2", kind: .photo, source: .solidColor(squareSwatch)),
            FeedMediaItem(
                id: "shape-3",
                kind: .photo,
                source: .assetPath("assets/friends/roh.png")
            ),
        ],
        locationTitle: "Ocean Beach",
        dateTimeLabel: "Sun · 11:00 AM"
    )

    /// Empty / unavailable media — polished placeholder.
    static let missingMedia = FeedMediaCarouselData(
        id: "fixture-missing",
        items: [
            FeedMediaItem(id: "missing-0", kind: .photo, source: .missing),
        ],
        locationTitle: "TBD",
        dateTimeLabel: "Date · Time"
    )

    /// Loading media state.
    static let loadingMedia = FeedMediaCarouselData(
        id: "fixture-loading",
        items: [
            FeedMediaItem(id: "loading-0", kind: .photo, source: .loading),
            FeedMediaItem(id: "loading-1", kind: .photo, source: .loading),
        ],
        locationTitle: "Loading…",
        dateTimeLabel: "—"
    )

    /// Multi-photo stack using bundled friend images (realistic crop demo).
    static let threeBundlePhotos = FeedMediaCarouselData(
        id: "fixture-three-bundle",
        items: [
            FeedMediaItem(id: "bundle-0", kind: .photo, source: .assetPath("assets/friends/ohm.png")),
            FeedMediaItem(id: "bundle-1", kind: .photo, source: .assetPath("assets/friends/viplove.png")),
            FeedMediaItem(id: "bundle-2", kind: .photo, source: .assetPath("assets/friends/ram.png")),
        ],
        locationTitle: "The Beehive",
        dateTimeLabel: "Fri · 9:15 PM"
    )

    /// Mixed photo + video poster (video is still frame only — no playback).
    static let photoAndVideoPoster = FeedMediaCarouselData(
        id: "fixture-photo-video",
        items: [
            FeedMediaItem(
                id: "pv-0",
                kind: .photo,
                source: .assetPath("assets/friends/ishan.png")
            ),
            FeedMediaItem(
                id: "pv-1",
                kind: .video,
                source: .assetPath("assets/friends/nitin.png")
            ),
        ],
        locationTitle: "Mission Cliffs",
        dateTimeLabel: "Thu · 7:00 PM"
    )

    /// Default vertical stack shown on the Pushes tab for this foundation step.
    /// Real photos first so the production crop/frame reads immediately.
    static let feedPushesPreviewStack: [FeedMediaCarouselData] = [
        threeBundlePhotos,
        photoAndVideoPoster,
        singlePhoto,
        threeMixedAspectPhotos,
        mixedPortraitLandscapeSquare,
        loadingMedia,
        missingMedia,
    ]
}

// MARK: - Solid image render

enum FeedMediaImageFactory {
    /// Clean solid fill at the swatch's source size — no labels or demo bands.
    /// Different source sizes still exercise fill-crop against the fixed frame.
    static func image(for swatch: FeedSolidMediaSwatch) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: swatch.size, format: format)
        return renderer.image { ctx in
            swatch.uiColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: swatch.size))
        }
    }
}
