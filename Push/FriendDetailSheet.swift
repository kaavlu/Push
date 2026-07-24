//
//  FriendDetailSheet.swift
//  Push
//

import SwiftUI

// MARK: - View Data Adapter

struct FriendDetailViewData {
    let friend: FriendPuckData

    var displayLocation: String {
        if let label = friend.locationLabel { return label }
        for prefix in ["Eating at ", "At the ", "At ", "Near "] {
            if friend.venueStatusText.hasPrefix(prefix) {
                return String(friend.venueStatusText.dropFirst(prefix.count))
            }
        }
        return friend.venueStatusText
    }

    var activityPrefix: String {
        switch friend.activity.lowercased() {
        case "coffee":          return "Working at"
        case "park":            return "Chilling at"
        case "gym":             return "Working out at"
        case "lunch", "food":   return "Eating at"
        case "dinner":          return "Dinner at"
        case "work":            return "Working at"
        case "driving":         return "Driving to"
        default:                return "At"
        }
    }

    var statusLine: String {
        let place = friend.placeName ?? displayLocation
        return "\(activityPrefix) \(place)"
    }
}

// MARK: - Sheet Root

struct FriendDetailSheet: View {
    let puck: MapPuckData
    var onStartPush: (StartPushLaunchContext) -> Void = { _ in }
    @State private var toastMessage: String?

    private var isHangout: Bool {
        puck.kind == .hangout || puck.kind == .cluster
    }

    var body: some View {
        ZStack(alignment: .top) {
            sheetContent

            if let message = toastMessage {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.activeForeground)
                    .padding(.horizontal, FriendDetailSheetLayout.toastHorizontalPadding)
                    .padding(.vertical, FriendDetailSheetLayout.toastVerticalPadding)
                    .pushGlassBackground(cornerRadius: FriendDetailSheetLayout.toastCornerRadius)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, FriendDetailSheetLayout.toastTopPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var sheetContent: some View {
        if puck.kind == .individual, let friend = puck.people.first {
            individualContent(friend: friend)
        } else if isHangout {
            hangoutContent(people: puck.people)
        } else if puck.kind == .friendGroup {
            friendGroupContent()
        }
    }

    // MARK: - Individual Layout

    private func individualContent(friend: FriendPuckData) -> some View {
        let viewData = FriendDetailViewData(friend: friend)
        return VStack(spacing: FriendDetailSheetLayout.sectionSpacing) {
            FriendDetailHeader(viewData: viewData)
            FriendActivityStatusCard(viewData: viewData)
            FriendDetailActionCards(
                onDirections: { triggerToast("Opening in Maps…") },
                onStartPlan: { startPush(with: .friends([friend.id], locationHint: friend.placeName)) }
            )
        }
        .padding(.horizontal, FriendDetailSheetLayout.contentHorizontalPadding)
        .padding(.top, FriendDetailSheetLayout.heroTopPadding)
        .padding(.bottom, FriendDetailSheetLayout.actionBottomPadding)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Hangout Layout (pair + small group)

    private func hangoutContent(people: [FriendPuckData]) -> some View {
        VStack(spacing: FriendDetailSheetLayout.sectionSpacing) {
            HangoutMomentHeader(puck: puck)
            HangoutMemberRow(people: people)
            PairSharedActivityCard(puck: puck)
            PairActionRow(
                onDirections: { triggerToast("Opening in Maps…") },
                onAskToJoin: { triggerToast("Request sent") },
                onStartPlan: { startPush(with: .from(puck: puck)) }
            )
        }
        .padding(.horizontal, FriendDetailSheetLayout.contentHorizontalPadding)
        .padding(.top, FriendDetailSheetLayout.heroTopPadding)
        .padding(.bottom, FriendDetailSheetLayout.actionBottomPadding)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Friend Group Layout

    private func friendGroupContent() -> some View {
        let members = Array(puck.people.dropFirst())
        return VStack(spacing: FriendDetailSheetLayout.sectionSpacing) {
            FriendGroupHeader(puck: puck)
            HangoutMemberRow(people: members)
            PairSharedActivityCard(puck: puck)
            PairActionRow(
                onDirections: { triggerToast("Opening in Maps…") },
                onAskToJoin: { triggerToast("Request sent") },
                onStartPlan: { startPush(with: .from(puck: puck)) }
            )
        }
        .padding(.horizontal, FriendDetailSheetLayout.contentHorizontalPadding)
        .padding(.top, FriendDetailSheetLayout.heroTopPadding)
        .padding(.bottom, FriendDetailSheetLayout.actionBottomPadding)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func triggerToast(_ message: String) {
        withAnimation(PushMotion.hangoutReveal) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(PushMotion.hangoutReveal) {
                toastMessage = nil
            }
        }
    }

    private func startPush(with context: StartPushLaunchContext) {
        onStartPush(context)
    }

}

// MARK: - Individual: Header

private struct FriendDetailHeader: View {
    let viewData: FriendDetailViewData

    private var friend: FriendPuckData { viewData.friend }
    private var accentColor: Color { friend.availability.accentColor }

    var body: some View {
        HStack(alignment: .center, spacing: FriendDetailSheetLayout.headerSpacing) {
            ProfilePhotoAvatar(
                imageAssetName: friend.profileImageAssetName,
                fallbackInitials: friend.avatarPlaceholder
            )
            .frame(
                width: FriendDetailSheetLayout.headerAvatarSize,
                height: FriendDetailSheetLayout.headerAvatarSize
            )
            .availabilityPulse(
                color: accentColor,
                lineWidth: FriendPuckLayout.statusRingWidth
            )

            VStack(alignment: .leading, spacing: FriendDetailSheetLayout.headerTextSpacing) {
                Text(friend.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PushControlColors.textEspresso)

                Text(viewData.displayLocation)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PushControlColors.textSecondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .center, spacing: 6) {
                PushAvailabilityChip(availability: friend.availability, density: .sheet)

                HStack(spacing: 4) {
                    Circle()
                        .fill(accentColor)
                        .frame(
                            width: FriendDetailSheetLayout.headerLiveIndicatorSize,
                            height: FriendDetailSheetLayout.headerLiveIndicatorSize
                        )
                    Text(friend.lastUpdated)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PushControlColors.textEspresso)
                }
            }
        }
    }
}

// MARK: - Individual: Activity Status Card

private struct FriendActivityStatusCard: View {
    let viewData: FriendDetailViewData

    private var accentColor: Color { viewData.friend.availability.accentColor }

    var body: some View {
        HStack(alignment: .center, spacing: FriendDetailSheetLayout.statusCardIconSpacing) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(FriendDetailSheetLayout.statusCardIconCircleOpacity))
                    .frame(
                        width: FriendDetailSheetLayout.statusCardIconCircleSize,
                        height: FriendDetailSheetLayout.statusCardIconCircleSize
                    )

                Image(systemName: viewData.friend.activitySymbolName)
                    .font(.system(size: FriendDetailSheetLayout.statusCardIconSize, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            Text(viewData.statusLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(FriendDetailSheetLayout.statusCardPadding)
        .pushGlassBackground(cornerRadius: FriendDetailSheetLayout.statusCardCornerRadius)
        .overlay {
            RoundedRectangle(
                cornerRadius: FriendDetailSheetLayout.statusCardCornerRadius,
                style: .continuous
            )
            .fill(accentColor.opacity(FriendDetailSheetLayout.statusCardAccentTintOpacity))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: FriendDetailSheetLayout.statusCardCornerRadius,
                style: .continuous
            )
            .stroke(
                accentColor.opacity(FriendDetailSheetLayout.statusCardAccentStrokeOpacity),
                lineWidth: FriendDetailSheetLayout.statusCardStrokeWidth
            )
        }
    }
}

// MARK: - Individual: Action Cards

private struct FriendDetailActionCards: View {
    let onDirections: () -> Void
    let onStartPlan: () -> Void

    var body: some View {
        HStack(spacing: FriendDetailSheetLayout.actionSpacing) {
            PrimaryActionCard(
                label: "Directions",
                symbolName: "arrow.triangle.turn.up.right.circle.fill",
                action: onDirections
            )
            PrimaryActionCard(
                label: "Start push",
                symbolName: "calendar.badge.plus",
                action: onStartPlan
            )
        }
    }
}

private struct PrimaryActionCard: View {
    let label: String
    let symbolName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FriendDetailSheetLayout.actionCardLabelSpacing) {
                Image(systemName: symbolName)
                    .font(.system(size: FriendDetailSheetLayout.actionCardIconSize, weight: .semibold))
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(PushControlColors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: FriendDetailSheetLayout.actionCardHeight)
            .pushGlassBackground(cornerRadius: FriendDetailSheetLayout.actionCardCornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Hangout: Shared Moment Header

private struct HangoutMomentHeader: View {
    let puck: MapPuckData

    private var accentColor: Color { puck.availability.accentColor }

    private var title: String {
        puck.people.count == 2
            ? FriendDetailSheetContent.pairTitle(for: puck.people)
            : FriendDetailSheetContent.hangoutHeadline(for: puck.people)
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: FriendDetailSheetLayout.hangoutMomentHeaderSpacing) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PushControlColors.textEspresso)

                Text(puck.people.first?.locationLabel ?? puck.venueStatusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PushControlColors.textSecondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .center, spacing: 6) {
                PushAvailabilityChip(availability: puck.availability, density: .sheet)

                HStack(spacing: 4) {
                    Circle()
                        .fill(accentColor)
                        .frame(
                            width: FriendDetailSheetLayout.headerLiveIndicatorSize,
                            height: FriendDetailSheetLayout.headerLiveIndicatorSize
                        )
                    Text(puck.people.first?.lastUpdated ?? "Just now")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PushControlColors.textEspresso)
                }
            }
        }
    }
}

// MARK: - Hangout: Identity Member Row

private struct HangoutMemberRow: View {
    let people: [FriendPuckData]

    private var avatarSize: CGFloat {
        people.count == 2
            ? FriendDetailSheetLayout.pairMemberTileAvatarSize
            : FriendDetailSheetLayout.groupMemberTileAvatarSize
    }

    private var tileSpacing: CGFloat {
        people.count == 2
            ? FriendDetailSheetLayout.pairMemberTileSpacing
            : FriendDetailSheetLayout.groupMemberTileSpacing
    }

    var body: some View {
        HStack(spacing: tileSpacing) {
            Spacer(minLength: 0)
            ForEach(people) { person in
                HangoutMemberTile(person: person, avatarSize: avatarSize)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct HangoutMemberTile: View {
    let person: FriendPuckData
    let avatarSize: CGFloat

    var body: some View {
        VStack(spacing: FriendDetailSheetLayout.hangoutMemberTileNameSpacing) {
            ProfilePhotoAvatar(
                imageAssetName: person.profileImageAssetName,
                fallbackInitials: person.avatarPlaceholder
            )
            .frame(width: avatarSize, height: avatarSize)
            .availabilityPulse(
                color: person.availability.accentColor,
                lineWidth: FriendPuckLayout.statusRingWidth
            )

            Text(person.isCurrentUser ? "You" : FriendDetailSheetContent.firstName(person))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
        }
    }
}

// MARK: - Pair Hangout: Shared Activity Card

private struct PairSharedActivityCard: View {
    let puck: MapPuckData

    private var accentColor: Color { puck.availability.accentColor }
    private var activitySymbol: String { puck.people.first?.activitySymbolName ?? "mappin" }
    private var activityLine: String {
        FriendDetailSheetContent.hangoutActivityLine(
            activity: puck.activity,
            venueStatusText: puck.venueStatusText
        )
    }
    var body: some View {
        HStack(alignment: .center, spacing: FriendDetailSheetLayout.statusCardIconSpacing) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(FriendDetailSheetLayout.statusCardIconCircleOpacity))
                    .frame(
                        width: FriendDetailSheetLayout.statusCardIconCircleSize,
                        height: FriendDetailSheetLayout.statusCardIconCircleSize
                    )

                Image(systemName: activitySymbol)
                    .font(.system(size: FriendDetailSheetLayout.statusCardIconSize, weight: .semibold))
                    .foregroundStyle(accentColor)
            }

            Text(activityLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(FriendDetailSheetLayout.statusCardPadding)
        .pushGlassBackground(cornerRadius: FriendDetailSheetLayout.statusCardCornerRadius)
        .overlay {
            RoundedRectangle(
                cornerRadius: FriendDetailSheetLayout.statusCardCornerRadius,
                style: .continuous
            )
            .fill(accentColor.opacity(FriendDetailSheetLayout.statusCardAccentTintOpacity))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: FriendDetailSheetLayout.statusCardCornerRadius,
                style: .continuous
            )
            .stroke(
                accentColor.opacity(FriendDetailSheetLayout.statusCardAccentStrokeOpacity),
                lineWidth: FriendDetailSheetLayout.statusCardStrokeWidth
            )
        }
    }
}

// MARK: - Pair Hangout: Actions

private struct PairActionRow: View {
    let onDirections: () -> Void
    let onAskToJoin: () -> Void
    let onStartPlan: () -> Void

    var body: some View {
        // Match individual action layout: fixed HStack avoids ViewThatFits
        // reflow mid-presentation (which made the three buttons pop early).
        HStack(spacing: FriendDetailSheetLayout.actionSpacing) {
            PrimaryActionCard(
                label: "Directions",
                symbolName: "arrow.triangle.turn.up.right.circle.fill",
                action: onDirections
            )
            PrimaryActionCard(label: "Ask to join", symbolName: "figure.wave", action: onAskToJoin)
            PrimaryActionCard(label: "Start push", symbolName: "calendar.badge.plus", action: onStartPlan)
        }
    }
}

// MARK: - Friend Group: Header

private struct FriendGroupHeader: View {
    let puck: MapPuckData

    private var groupPuck: FriendPuckData? { puck.people.first }
    private var accentColor: Color { puck.availability.accentColor }

    var body: some View {
        HStack(alignment: .center, spacing: FriendDetailSheetLayout.headerSpacing) {
            ProfilePhotoAvatar(
                imageAssetName: groupPuck?.profileImageAssetName,
                fallbackInitials: groupPuck?.avatarPlaceholder ?? "GR"
            )
            .frame(
                width: FriendDetailSheetLayout.headerAvatarSize,
                height: FriendDetailSheetLayout.headerAvatarSize
            )
            .availabilityPulse(
                color: accentColor,
                lineWidth: FriendPuckLayout.statusRingWidth
            )

            VStack(alignment: .leading, spacing: FriendDetailSheetLayout.headerTextSpacing) {
                Text(groupPuck?.name ?? "Group")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PushControlColors.textEspresso)

                Text(groupPuck?.locationLabel ?? puck.venueStatusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PushControlColors.textSecondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .center, spacing: 6) {
                PushAvailabilityChip(availability: puck.availability, density: .sheet)

                HStack(spacing: 4) {
                    Circle()
                        .fill(accentColor)
                        .frame(
                            width: FriendDetailSheetLayout.headerLiveIndicatorSize,
                            height: FriendDetailSheetLayout.headerLiveIndicatorSize
                        )
                    Text(groupPuck?.lastUpdated ?? "Just now")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PushControlColors.textEspresso)
                }
            }
        }
    }
}
