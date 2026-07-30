//
//  AddYoursModels.swift
//  Push
//
//  Launch context, draft media, phase, and copy for Add Yours. The view model
//  (append path) lives in `AddYoursViewModel` / `AddYoursViewModel+Append`.
//

import Foundation
import SwiftUI

// MARK: - Launch context

/// Payload when opening Add Yours from a Moment card. Only the Moment identity
/// travels: everything the screen shows is loaded from `MomentRepository`, so a
/// stale Feed card can never become the source of truth (architecture §6.4).
struct AddYoursContext: Identifiable, Equatable {
    let momentID: Moment.ID

    /// `fullScreenCover(item:)` identity — one sheet per Moment.
    var id: String { momentID }

    init(momentID: Moment.ID) {
        self.momentID = momentID
    }

    /// The Feed card id **is** the Moment id (S6 `MomentFeedCardBuilder`).
    init(carousel: FeedMediaCarouselData) {
        self.momentID = carousel.id
    }

    /// Instructional subtitle — fixed product copy (no location).
    var subtitle: String {
        AddYoursCopy.subtitle
    }
}

// MARK: - Draft media

struct AddYoursDraftItem: Identifiable {
    let id: UUID
    let kind: FeedMediaKind
    /// Decoded still for photos; optional poster for videos (nil → branded placeholder).
    let previewImage: UIImage?
    /// Processed bytes for publish. Nil for prefilled media that already lives in
    /// Storage (existing-Moment edit) and for preview/test drafts — those items
    /// can be shown but never re-uploaded.
    let upload: MomentMediaUpload?

    init(
        id: UUID = UUID(),
        kind: FeedMediaKind,
        previewImage: UIImage?,
        upload: MomentMediaUpload? = nil
    ) {
        self.id = id
        self.kind = kind
        self.previewImage = previewImage
        self.upload = upload
    }
}

// MARK: - Phase

enum AddYoursPhase: Equatable {
    case composing
    case submitting
    case success
}

// MARK: - Timing (injectable for tests)

struct AddYoursTiming {
    var submitDelayNanoseconds: UInt64
    var successHoldNanoseconds: UInt64

    static let production = AddYoursTiming(
        submitDelayNanoseconds: 380_000_000,
        successHoldNanoseconds: 950_000_000
    )

    static let immediate = AddYoursTiming(
        submitDelayNanoseconds: 0,
        successHoldNanoseconds: 0
    )
}

// MARK: - Copy

enum AddYoursCopy {
    static let title = "Add yours"
    static let subtitle = "Share photos and videos"
    static let emptyPrompt = "Choose from library"
    static let emptyHint = "Photos and videos · up to \(AddYoursLayout.maxSelectionCount)"
    static let selectedSection = "Selected"
    static let addMoreAccessibility = "Add more media"
    static let removeAccessibility = "Remove media"
    static let primaryAction = "Add to push"
    static let submittingAction = "Adding…"
    static let successTitle = "Added to push"
    static let successMessage = "Your media is ready to share with the group."
    static let videoBadgeAccessibility = "Video"

    /// Repository surface name for the shared failed/loading states.
    static let surfaceName = "this moment"
    /// The viewer lost `canAddMedia` (untagged, blocked, or the album is gone).
    static let deniedTitle = "You can't add to this moment"
    static let deniedMessage = "Only people tagged in it can add photos and videos."
    /// Cap already reached before anything was picked.
    static let fullTitle = "This moment is full"
    static let fullMessage = "It already has \(MomentLimits.maxActiveMedia) photos and videos."

    static func selectedCountLabel(count: Int, max: Int) -> String {
        "\(count) of \(max)"
    }
}

// MARK: - Selection helper

enum AddYoursSelection {
    static func clampedIndex(_ index: Int, itemCount: Int) -> Int {
        guard itemCount > 0 else { return 0 }
        return min(max(0, index), itemCount - 1)
    }
}

// MARK: - Fixtures (DEBUG / previews)

enum AddYoursFixtures {
    static let sampleMomentID = "fixture-addyours-dolores"
    static let sampleContext = AddYoursContext(momentID: sampleMomentID)
    private static let sampleViewerID = "you"

    /// Preview-only stand-in for a loaded `MomentDetail`. The app path always
    /// gets this from `MomentRepository.moment(id:)`.
    static var previewDetail: MomentDetail {
        let publishedAt = Date().addingTimeInterval(-3 * 60 * 60)
        return MomentDetail(
            moment: Moment(
                id: sampleMomentID,
                creatorID: sampleViewerID,
                title: "Dolores Park",
                locationText: "Dolores Park",
                placeID: nil,
                pushID: nil,
                publishedAt: publishedAt,
                lastActivityAt: publishedAt,
                deletedAt: nil
            ),
            members: [
                MomentMember(
                    id: "\(sampleMomentID)-member",
                    momentID: sampleMomentID,
                    personID: sampleViewerID,
                    taggedAt: publishedAt
                )
            ],
            media: [],
            capabilities: MomentCapabilities(
                viewerID: sampleViewerID,
                canView: true,
                canAddMedia: true,
                canEditTags: true,
                canEditMetadata: true,
                canReorderMedia: true,
                canDeleteMoment: true,
                canSelfRemoveTag: false,
                youContributed: false,
                showOpenForAddsChip: true,
                isCreator: true
            )
        )
    }

    static func sampleDraftItems() -> [AddYoursDraftItem] {
        let paths = [
            "assets/friends/ohm.png",
            "assets/friends/viplove.png",
            "assets/friends/ram.png",
        ]
        var drafts: [AddYoursDraftItem] = paths.compactMap { path in
            guard let image = loadBundleImage(path: path) else { return nil }
            return AddYoursDraftItem(kind: .photo, previewImage: image)
        }
        drafts.append(AddYoursDraftItem(kind: .video, previewImage: nil))
        return drafts
    }

    private static func loadBundleImage(path: String) -> UIImage? {
        AvatarImageLoader.localImage(for: path)
    }
}
