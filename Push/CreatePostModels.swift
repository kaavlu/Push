//
//  CreatePostModels.swift
//  Push
//
//  Presentation models + copy for the Feed create-post flow (hub → compose).
//  Chooser rows and the friend catalog are repository-backed (S7); the fixtures
//  at the bottom exist only for previews and the design lab.
//

import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Screens & source

enum CreatePostScreen: Equatable {
    case hub
    /// Start Push–style multi-select friends (scratch entry or edit from compose).
    case selectFriends
    case compose
}

/// How the friend picker was entered — drives back behavior and stack path.
enum CreatePostFriendPickerEntry: Equatable {
    /// Create from scratch first step — Back returns to hub.
    case initialScratch
    /// Opened from compose “With · Edit” — Back returns to compose (discards unapplied picks).
    case editFromCompose
}

enum CreatePostSource: Equatable {
    case scratch
    case existingMoment(id: String)
    case pastPush(id: String)
}

enum CreatePostPhase: Equatable {
    case composing
    case submitting
    case success
}

enum CreatePostHubSegment: String, CaseIterable, Identifiable {
    case existingMoments
    case pastPushes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .existingMoments: return CreatePostCopy.segmentExistingMoments
        case .pastPushes: return CreatePostCopy.segmentPastPushes
        }
    }
}

/// Existing Moment status — only two pills; “You contributed” wins over open.
enum CreatePostContributionState: String, Equatable {
    case openForAdds
    case youContributed

    var chipTitle: String {
        switch self {
        case .openForAdds: return CreatePostCopy.contributionOpenForAdds
        case .youContributed: return CreatePostCopy.contributionYouContributed
        }
    }

    var chipKind: PushContributionChipKind {
        switch self {
        case .openForAdds: return .openForAdds
        case .youContributed: return .youContributed
        }
    }

    /// Priority: you contributed → open for adds.
    static func resolved(youContributed: Bool, openForAdds: Bool) -> CreatePostContributionState {
        if youContributed { return .youContributed }
        if openForAdds { return .openForAdds }
        // Closed without a contribution still surfaces the open chip only when allowed;
        // fixtures always set one explicit state.
        return .openForAdds
    }
}

enum CreatePostChooserStyle: Equatable {
    /// Moment already exists — media thumb + contribution chip.
    case existingMoment(CreatePostContributionState)
    /// Past Push without a moment yet — people/context only, no media thumb.
    case pastPush
}

// MARK: - Chooser row model

/// Presentation row for an Existing Moment (`Moment.ID`) or a Past Push
/// (`PushPlan.ID`) in the hub chooser.
struct CreatePostHistoryItem: Identifiable, Equatable {
    let id: String
    let title: String
    let dateLabel: String
    let locationTitle: String
    /// Everyone present on the original Push (edit page “With” list).
    let participants: [FeedMediaParticipant]
    /// People who contributed media/content to the moment (row avatar stack).
    let contributors: [FeedMediaParticipant]
    let mediaItems: [FeedMediaItem]
    let style: CreatePostChooserStyle

    /// Builds an existing-moment chooser row from a feed carousel (edit-from-feed).
    /// The card id **is** the `Moment.ID` since Feed reads from the repository (S6).
    static func fromFeedCarousel(_ carousel: FeedMediaCarouselData) -> CreatePostHistoryItem {
        CreatePostHistoryItem(
            id: carousel.id,
            title: carousel.title,
            dateLabel: carousel.dateTimeLabel,
            locationTitle: carousel.locationTitle,
            participants: carousel.participants,
            contributors: carousel.participants,
            mediaItems: carousel.items,
            style: .existingMoment(.youContributed)
        )
    }

    var showsMediaThumbnail: Bool {
        if case .existingMoment = style { return true }
        return false
    }

    var contributionState: CreatePostContributionState? {
        if case .existingMoment(let state) = style { return state }
        return nil
    }

    var hasRenderableMedia: Bool {
        carouselThumbnailMedia != nil
    }

    /// First carousel item — preferred leading thumbnail source.
    var carouselFirstMedia: FeedMediaItem? {
        mediaItems.first
    }

    /// First carousel item that can render, else first item.
    var carouselThumbnailMedia: FeedMediaItem? {
        if let first = mediaItems.first {
            switch first.source {
            case .assetPath, .solidColor:
                return first
            case .loading, .missing:
                break
            }
        }
        return mediaItems.first { item in
            switch item.source {
            case .assetPath, .solidColor: return true
            case .loading, .missing: return false
            }
        }
    }

    /// Total photos + videos in the moment carousel.
    var mediaCount: Int {
        mediaItems.count
    }

    var metaLine: String {
        [dateLabel, locationTitle]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Combined media count label (photo icon always — not video-specific).
    var mediaCountLabel: String? {
        let count = mediaCount
        guard count > 0 else { return nil }
        return "\(count)"
    }

    var mediaSymbolName: String {
        PushMomentChooserMetrics.mediaSymbolName
    }

    var mediaAccessibilityLabel: String {
        let count = mediaCount
        guard count > 0 else { return "" }
        return count == 1 ? "1 media item" : "\(count) media items"
    }

    var participantCountLabel: String {
        let count = participants.count
        guard count > 0 else { return "" }
        return count == 1 ? "1 person" : "\(count) people"
    }

    /// Display-only person rows for the edit “With” section.
    var memberPersonRows: [FriendRowModel] {
        participants.map { person in
            FriendRowModel(
                id: person.id,
                friend: FriendPuckData(
                    id: person.id,
                    name: person.displayName,
                    avatarPlaceholder: person.initials,
                    profileImageAssetName: person.imageAssetPath,
                    activity: "",
                    activitySymbolName: "",
                    activityDisplayText: "",
                    availability: .busy,
                    venueStatusText: "",
                    lastUpdated: ""
                ),
                groupLabel: nil
            )
        }
    }
}

// MARK: - Timing

struct CreatePostTiming {
    var submitDelayNanoseconds: UInt64
    var successHoldNanoseconds: UInt64

    static let production = CreatePostTiming(
        submitDelayNanoseconds: 380_000_000,
        successHoldNanoseconds: 900_000_000
    )

    static let immediate = CreatePostTiming(
        submitDelayNanoseconds: 0,
        successHoldNanoseconds: 0
    )
}

// MARK: - Copy

enum CreatePostCopy {
    static let hubTitle = "Share a moment"
    /// "Couldn't load moments" in the shared failed surface.
    static let hubSurfaceName = "moments"
    static let hubSubtitle = "Create new or revisit one you've posted"
    static let createFromScratchTitle = "Create from scratch"
    static let createFromScratchSubtitle = "Add photos and write your own."
    static let segmentExistingMoments = "Existing Moments"
    static let segmentPastPushes = "Past Pushes"
    static let existingMomentsEmptyTitle = "No moments yet"
    static let existingMomentsEmptyMessage = "Moments you post will show up here."
    static let pastPushesEmptyTitle = "No past Pushes"
    static let pastPushesEmptyMessage = "When a Push finishes, you can turn it into a moment."
    static let contributionOpenForAdds = "Open for adds"
    static let contributionYouContributed = "You contributed"
    static let pastPushContextLabel = "Push"
    static let composeTitle = "New post"
    static let composeEditTitle = "Edit moment"
    static let composeFromPastSubtitle = "Add media to turn this Push into a moment."
    static let composeFromExistingSubtitle = "Tweak media and details before sharing."
    static let composeFromScratchSubtitle = "Add photos and a short title."
    static let selectFriendsTitle = "Who was there?"
    static let selectFriendsSubtitle = "Tag friends in this moment — or skip and go solo."
    static let selectFriendsSearchPlaceholder = "Search friends"
    static let selectFriendsSection = "Friends"
    static let selectFriendsNext = "Next"
    static let selectFriendsDone = "Done"
    static let selectFriendsEmptyTitle = "No friends yet"
    static let selectFriendsEmptyMessage = "Add friends to tag them on moments."
    static let titlePlaceholder = "Title"
    static let locationPlaceholder = "Location"
    static let peopleSection = "With"
    static let peopleEditAction = "Edit"
    static let peopleEmptyMessage = "No one tagged yet"
    static let primaryAction = "Share post"
    static let submittingAction = "Sharing…"
    static let editPrimaryAction = "Save changes"
    static let editSubmittingAction = "Saving…"
    static let successTitle = "Posted"
    static let successMessage = "Your moment is ready for the feed."
    static let backAccessibility = "Back"
    static let closeAccessibility = "Close"
    static let videoBadgeAccessibility = "Video"
    static let mediaSelectedSection = "Selected"
    static let mediaCoverBadge = "Cover"
    static let mediaReorderHint = "Drag to reorder. First item is the feed thumbnail."

    static func selectedCountLabel(count: Int, max: Int) -> String {
        "\(count) of \(max)"
    }
}

// MARK: - Fixtures

/// Preview / design-lab only. The app builds these rows from repositories
/// (`CreatePostHubBuilder`), so fixtures can never reach a live session.
enum CreatePostFixtures {
    /// Friends available to tag on create-from-scratch (fixture / local only).
    static let selectableFriends: [PushRecipientItem] = {
        let people: [(id: String, name: String, path: String)] = [
            ("p-ohm", "Ohm", "assets/friends/ohm.png"),
            ("p-viplove", "Viplove", "assets/friends/viplove.png"),
            ("p-ram", "Ram", "assets/friends/ram.png"),
            ("p-pranay", "Pranay", "assets/friends/pranay.png"),
            ("p-ishan", "Ishan", "assets/friends/ishan.png"),
            ("p-nitin", "Nitin", "assets/friends/nitin.png"),
            ("p-roh", "Roh", "assets/friends/roh.png"),
            ("p-ryan", "Ryan", "assets/friends/ryan.png"),
        ]
        return people.map { person in
            PushRecipientItem(
                id: person.id,
                name: person.name,
                memberCount: nil,
                imageAssetName: person.path,
                initials: initials(for: person.name),
                isGroup: false
            )
        }
    }()

    private static func initials(for name: String) -> String {
        let parts = name.split(separator: " ").map(String.init)
        let letters = parts.prefix(2).compactMap(\.first).map(String.init)
        let joined = letters.joined().uppercased()
        return joined.isEmpty ? "?" : joined
    }

    /// Moments already on the feed (media + contribution state).
    static let existingMoments: [CreatePostHistoryItem] = [
        moment(
            from: FeedMediaCarouselFixtures.threeBundlePhotos,
            title: "Friday night out",
            contribution: .openForAdds,
            // Subset of Push members who actually posted media.
            contributorIDs: ["p-ohm", "p-viplove"]
        ),
        moment(
            from: FeedMediaCarouselFixtures.photoAndVideoPoster,
            title: "Climbing session",
            contribution: .youContributed,
            contributorIDs: ["p-ishan", "p-nitin"]
        ),
        moment(
            from: FeedMediaCarouselFixtures.singlePhoto,
            title: "Dinner at home",
            contribution: .openForAdds,
            contributorIDs: ["p-pranay"]
        ),
    ]

    /// Completed Pushes that do not yet have a moment (no media thumbs).
    static let pastPushes: [CreatePostHistoryItem] = [
        pastPush(
            id: "past-push-park",
            title: "Park hang",
            dateLabel: "Sat · 4:30 PM",
            locationTitle: "Dolores Park",
            participants: FeedMediaCarouselFixtures.threeMixedAspectPhotos.participants
        ),
        pastPush(
            id: "past-push-beach",
            title: "Beach morning",
            dateLabel: "Sun · 11:00 AM",
            locationTitle: "Ocean Beach",
            participants: FeedMediaCarouselFixtures.mixedPortraitLandscapeSquare.participants
        ),
        pastPush(
            id: "past-push-tacos",
            title: "Taco night",
            dateLabel: "Thu · 7:45 PM",
            locationTitle: "Mission",
            participants: FeedMediaCarouselFixtures.threeBundlePhotos.participants
        ),
        pastPush(
            id: "past-push-walk",
            title: "Sunset walk",
            dateLabel: "Wed · 6:15 PM",
            locationTitle: "Crissy Field",
            participants: FeedMediaCarouselFixtures.photoAndVideoPoster.participants
        ),
    ]

    /// Combined fixture list (tests / previews that still want one array).
    static var historyItems: [CreatePostHistoryItem] {
        existingMoments + pastPushes
    }

    private static func moment(
        from carousel: FeedMediaCarouselData,
        title: String,
        contribution: CreatePostContributionState,
        contributorIDs: [String]
    ) -> CreatePostHistoryItem {
        let members = carousel.participants
        let idSet = Set(contributorIDs)
        let contributors = members.filter { idSet.contains($0.id) }
        return CreatePostHistoryItem(
            id: carousel.id,
            title: title.isEmpty ? carousel.title : title,
            dateLabel: carousel.dateTimeLabel,
            locationTitle: carousel.locationTitle,
            participants: members,
            contributors: contributors.isEmpty ? Array(members.prefix(1)) : contributors,
            mediaItems: carousel.items,
            style: .existingMoment(contribution)
        )
    }

    private static func pastPush(
        id: String,
        title: String,
        dateLabel: String,
        locationTitle: String,
        participants: [FeedMediaParticipant]
    ) -> CreatePostHistoryItem {
        CreatePostHistoryItem(
            id: id,
            title: title,
            dateLabel: dateLabel,
            locationTitle: locationTitle,
            participants: participants,
            contributors: [],
            mediaItems: [],
            style: .pastPush
        )
    }
}
