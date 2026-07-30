//
//  FriendDetailSheetStyle.swift
//  Push
//

import Foundation

enum FriendDetailSheetLayout {

    // MARK: - Shared

    static let heroTopPadding: CGFloat = 25
    /// Shared gap from the bottom of the action row to the content floor
    /// (above the home-indicator inset). Kept identical for individual and
    /// multi-person sheets so map popups feel standardized.
    static let actionBottomPadding: CGFloat = 14
    static let actionSpacing: CGFloat = 10

    // MARK: - Individual: Section

    static let sectionSpacing: CGFloat = 10
    static let contentHorizontalPadding: CGFloat = 20

    // MARK: - Individual: Header

    static let headerAvatarSize: CGFloat = 62
    static let headerSpacing: CGFloat = 14
    static let headerTextSpacing: CGFloat = 4
    static let headerLiveIndicatorSize: CGFloat = 6

    // MARK: - Individual: Activity Status Card

    static let statusCardPadding: CGFloat = 14
    static let statusCardCornerRadius: CGFloat = 20
    static let statusCardIconSpacing: CGFloat = 14
    static let statusCardIconSize: CGFloat = 18
    static let statusCardIconCircleSize: CGFloat = 44
    static let statusCardIconCircleOpacity: CGFloat = 0.18
    static let statusCardAccentTintOpacity: CGFloat = 0.08
    static let statusCardAccentStrokeOpacity: CGFloat = 0.20
    static let statusCardStrokeWidth: CGFloat = 0.8

    // MARK: - Compact map puck sheet (individual + multi-person, Issue #139)

    static let sheetCornerRadius: CGFloat = 32

    /// Height for map puck detail sheets.
    /// Multi-person adds a fixed Who’s here block (2-row grid; overflow scrolls
    /// inside that block). Join CTA absence still subtracts one action row.
    static func compactSheetHeight(
        _ layout: PushAdaptiveLayout,
        showsAskToJoin: Bool = true,
        isMultiPerson: Bool = false
    ) -> CGFloat {
        var height = layout.value(compact: 246, standard: 238, large: 232)
        if isMultiPerson {
            height += multiPersonSectionSpacing + whosHereBlockHeight
        }
        if !showsAskToJoin {
            height -= multiPersonSecondaryHeight + multiPersonActionsSpacing
        }
        return height
    }

    /// Legacy aliases.
    static func individualSheetHeight(_ layout: PushAdaptiveLayout) -> CGFloat {
        compactSheetHeight(layout, showsAskToJoin: true, isMultiPerson: false)
    }

    static func multiPersonSheetHeight(_ layout: PushAdaptiveLayout) -> CGFloat {
        compactSheetHeight(layout, showsAskToJoin: true, isMultiPerson: true)
    }

    static func hangoutSheetHeight(_ layout: PushAdaptiveLayout) -> CGFloat {
        compactSheetHeight(layout, showsAskToJoin: true, isMultiPerson: true)
    }

    static let multiPersonSectionSpacing: CGFloat = 12
    static let multiPersonInfoSpacing: CGFloat = 10
    static let multiPersonTextSpacing: CGFloat = 2
    static let multiPersonTrailingSpacing: CGFloat = 4
    static let multiPersonDividerOpacity = 0.14
    static let multiPersonDividerHeight: CGFloat = 1
    static let multiPersonActionsSpacing: CGFloat = 8
    /// Gap under the secondary action row, above the home-indicator inset.
    static let multiPersonActionBottomPadding: CGFloat = 4
    static let multiPersonSecondaryHeight: CGFloat = 44
    static let multiPersonSecondaryCornerRadius: CGFloat = 14
    static let multiPersonSecondaryIconSize: CGFloat = 14
    static let multiPersonSecondaryLabelSpacing: CGFloat = 5
    static let multiPersonSecondaryBorderOpacity = 0.40
    static let multiPersonSecondaryBorderWidth: CGFloat = 1.5
    /// Light fill for secondary actions over liquid-glass sheet.
    static let multiPersonSecondaryFillOpacity = 0.55
    static let multiPersonOverflowBadgeFillOpacity = 0.92
    static let multiPersonActivityIconSize: CGFloat = 12
    static let multiPersonActivityIconSpacing: CGFloat = 5
    static let multiPersonTopPadding: CGFloat = 26
    /// Avoid squashed subtitle text; truncate cleanly at the trailing edge.
    static let multiPersonSubtitleMinimumScale: CGFloat = 0.92

    // MARK: - Who’s here member grid

    static let whosHereTitle = "Who’s here"
    static let whosHereColumnCount = 3
    /// Show everyone when count ≤ this; above it, collapse to 5 + overflow.
    static let whosHereDirectShowLimit = 6
    static let whosHereCollapsedMemberSlots = 5
    static let whosHereGridSpacing: CGFloat = 8
    static let whosHerePuckHeight: CGFloat = 36
    static let whosHereAvatarSize: CGFloat = 22
    static let whosHereAvatarRingWidth: CGFloat = 1.5
    static let whosHerePuckHorizontalPadding: CGFloat = 8
    static let whosHereLabelSpacing: CGFloat = 6
    static let whosHereSectionLabelSpacing: CGFloat = 8
    static let whosHereExpandDragThreshold: CGFloat = 36
    static let whosHereGridRowsVisible = 2

    /// Fixed height for the member grid viewport (two rows + one inter-row gap).
    static var whosHereGridViewportHeight: CGFloat {
        CGFloat(whosHereGridRowsVisible) * whosHerePuckHeight
            + CGFloat(whosHereGridRowsVisible - 1) * whosHereGridSpacing
    }

    /// Label + spacing + two-row grid.
    static var whosHereBlockHeight: CGFloat {
        16 + whosHereSectionLabelSpacing + whosHereGridViewportHeight
    }

    // MARK: - Avatar stack (max 3 faces + overflow)

    static let multiPersonAvatarSize: CGFloat = 44
    static let multiPersonAvatarOverlap: CGFloat = 14
    static let multiPersonAvatarRingWidth: CGFloat = 2
    static let multiPersonVisibleAvatarLimit = 3
    static let multiPersonOverflowBadgeSize: CGFloat = 28
    static let multiPersonOverflowFontSize: CGFloat = 11

    /// Width for the visible faces (not always 3) so the text column gets more room.
    static func multiPersonAvatarStackWidth(visibleCount: Int) -> CGFloat {
        let count = max(1, min(visibleCount, multiPersonVisibleAvatarLimit))
        return multiPersonAvatarSize
            + CGFloat(count - 1) * (multiPersonAvatarSize - multiPersonAvatarOverlap)
    }

    // MARK: - Toast

    static let toastHorizontalPadding: CGFloat = 18
    static let toastVerticalPadding: CGFloat = 10
    static let toastCornerRadius: CGFloat = 22
    static let toastTopPadding: CGFloat = 12
}

enum FriendDetailSheetContent {
    /// Members shown in multi-person identity (drops synthetic friend-group avatar).
    static func displayMembers(for puck: MapPuckData) -> [FriendPuckData] {
        switch puck.kind {
        case .friendGroup:
            return Array(puck.people.dropFirst())
        case .hangout, .cluster, .individual:
            return puck.people
        }
    }

    /// Whether this puck uses the multi-person sheet (Who’s here grid).
    static func isMultiPerson(_ puck: MapPuckData) -> Bool {
        switch puck.kind {
        case .hangout, .cluster, .friendGroup:
            return true
        case .individual:
            return false
        }
    }

    /// Summary title for multi-person sheets — group context, not name list.
    /// Examples: `3 friends together`, `6 friends at Souvla`.
    static func groupContextTitle(for puck: MapPuckData) -> String {
        let members = displayMembers(for: puck)
        let count = members.count
        guard count > 0 else { return "Friends together" }
        let noun = count == 1 ? "friend" : "friends"
        let lead = members.first
        let venue = compactVenueLabel(
            venueStatusText: puck.venueStatusText,
            placeName: lead?.placeName ?? ""
        )
        if !venue.isEmpty {
            return "\(count) \(noun) at \(venue)"
        }
        return "\(count) \(noun) together"
    }

    /// Whether the Who’s here grid needs an overflow cell when collapsed.
    static func needsWhosHereOverflow(memberCount: Int) -> Bool {
        memberCount > FriendDetailSheetLayout.whosHereDirectShowLimit
    }

    /// Overflow remainder after showing `whosHereCollapsedMemberSlots` faces.
    static func whosHereOverflowCount(memberCount: Int) -> Int {
        max(0, memberCount - FriendDetailSheetLayout.whosHereCollapsedMemberSlots)
    }

    /// Title for compact individual sheets (full name) and legacy multi-name tests.
    /// 1: full display name · 2: `A & B` · 3: `A, B & C` · 4+: `A, B + N`.
    static func multiPersonTitle(for people: [FriendPuckData]) -> String {
        guard !people.isEmpty else { return "Group" }
        if people.count == 1 {
            let person = people[0]
            if person.isCurrentUser { return "You" }
            let full = person.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return full.isEmpty ? "Friend" : full
        }
        let names = people.map(firstName).filter { !$0.isEmpty }
        guard !names.isEmpty else { return "Group" }
        switch names.count {
        case 2:
            return "\(names[0]) & \(names[1])"
        case 3:
            return "\(names[0]), \(names[1]) & \(names[2])"
        default:
            let remainder = names.count - 2
            return "\(names[0]), \(names[1]) + \(remainder)"
        }
    }

    /// Sheet summary title: group context for multi-person, full name for individual.
    static func summaryTitle(for puck: MapPuckData) -> String {
        if isMultiPerson(puck) {
            return groupContextTitle(for: puck)
        }
        return multiPersonTitle(for: displayMembers(for: puck))
    }

    /// Shared activity + venue line for the multi-person subtitle.
    ///
    /// Prefer compact venue labels (`At Dolores`) over redundant long forms
    /// like `Park at Dolores Park Lawn`, which overflow the Friends-row column.
    static func multiPersonActivityLine(for puck: MapPuckData) -> String {
        let members = displayMembers(for: puck)
        let lead = members.first
        let activity = trimmed(lead?.activity ?? puck.activity)
        let placeFull = trimmed(lead?.placeName)
        let venueStatus = trimmed(puck.venueStatusText)
        let venueShort = compactVenueLabel(
            venueStatusText: venueStatus,
            placeName: placeFull
        )

        if activity.isEmpty {
            return hangoutActivityLine(
                activity: puck.activity,
                venueStatusText: puck.venueStatusText
            )
        }

        if activity.hasPrefix("At ") || activity.hasPrefix("Near ") {
            return activity
        }

        // Activity already names the full place ("At Dolores Park Lawn").
        if !placeFull.isEmpty, activity.localizedCaseInsensitiveContains(placeFull) {
            return activity
        }

        // Generic activity that is already part of the place name ("Park" ⊂
        // "Dolores Park Lawn") — use the compact venue, not "Park at … Lawn".
        if !placeFull.isEmpty,
           placeFull.range(of: activity, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
            if !venueShort.isEmpty {
                return venueStatus.hasPrefix("At ") || venueStatus.hasPrefix("Near ")
                    ? venueStatus
                    : "At \(venueShort)"
            }
            return activity
        }

        if !venueShort.isEmpty {
            return "\(activity) at \(venueShort)"
        }

        return activity
    }

    /// Address / location detail under activity. Nil when empty or duplicates venue.
    static func multiPersonLocationDetail(for puck: MapPuckData) -> String? {
        let members = displayMembers(for: puck)
        let lead = members.first
        let address = trimmed(lead?.locationLabel)
        guard !address.isEmpty else { return nil }

        let place = trimmed(lead?.placeName)
        if !place.isEmpty, address.caseInsensitiveCompare(place) == .orderedSame {
            return nil
        }

        let activityLine = multiPersonActivityLine(for: puck)
        if activityLine.localizedCaseInsensitiveContains(address) {
            return nil
        }

        // "Dolores Park, 19th St" under "At Dolores" is place-name noise, not a street pin.
        // Keep real street labels like "517 Hayes St" or "19th St & Dolores St".
        let addressPrimary = address
            .split(separator: ",", maxSplits: 1)
            .first
            .map { trimmed(String($0)) } ?? address
        if !place.isEmpty {
            if place.localizedCaseInsensitiveContains(addressPrimary)
                || addressPrimary.localizedCaseInsensitiveContains(place) {
                return nil
            }
            let compactPlace = compactVenueLabel(venueStatusText: "", placeName: place)
            if !compactPlace.isEmpty,
               addressPrimary.caseInsensitiveCompare(compactPlace) == .orderedSame {
                return nil
            }
        }
        if activityLine.localizedCaseInsensitiveContains(addressPrimary) {
            return nil
        }

        return address
    }

    /// Prefer puck venue short label (`At Dolores` → `Dolores`) over full place names.
    static func compactVenueLabel(venueStatusText: String, placeName: String) -> String {
        let venue = trimmed(venueStatusText)
        for prefix in ["At the ", "At ", "Near ", "Group forming near "] {
            if venue.hasPrefix(prefix) {
                let rest = trimmed(String(venue.dropFirst(prefix.count)))
                if !rest.isEmpty { return rest }
            }
        }
        let place = trimmed(placeName)
        guard !place.isEmpty else { return "" }
        // Drop verbose suffixes so "Dolores Park Lawn" / "Dolores Park" → "Dolores".
        for suffix in [" Park Lawn", " Park", " Fitness", " Lawn"] {
            if place.hasSuffix(suffix) {
                let base = trimmed(String(place.dropLast(suffix.count)))
                if !base.isEmpty { return base }
            }
        }
        return place
    }

    /// Freshness label for the trailing column.
    static func multiPersonFreshness(for puck: MapPuckData) -> String {
        let members = displayMembers(for: puck)
        let label = members.first?.lastUpdated
            ?? puck.people.first?.lastUpdated
            ?? ""
        let trimmedLabel = trimmed(label)
        return trimmedLabel.isEmpty ? "Just now" : trimmedLabel
    }

    /// Join CTA only when the shared state is joinable and viewer is not already in the puck.
    static func showsAskToJoin(for puck: MapPuckData) -> Bool {
        puck.availability == .joinable && !puck.includesCurrentUser
    }

    // MARK: - Legacy helpers (tests / older call sites)

    static func groupHeadline(for people: [FriendPuckData]) -> String {
        multiPersonTitle(for: people)
    }

    static func hangoutHeadline(for people: [FriendPuckData]) -> String {
        multiPersonTitle(for: people)
    }

    static func pairTitle(for people: [FriendPuckData]) -> String {
        multiPersonTitle(for: people)
    }

    static func pairMetadata(for people: [FriendPuckData]) -> String {
        let count = people.count
        let noun = count == 1 ? "friend" : "friends"
        return "\(count) \(noun) together"
    }

    /// Prefer the builder status line (note / activity / place); fall back to activity.
    static func hangoutActivityLine(activity: String, venueStatusText: String) -> String {
        PresenceActivityPresentation.detailStatusLine(
            activityName: activity,
            venueStatusText: venueStatusText
        )
    }

    static func firstName(_ person: FriendPuckData) -> String {
        if person.isCurrentUser { return "You" }
        return person.name.components(separatedBy: " ").first ?? person.name
    }

    private static func trimmed(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
