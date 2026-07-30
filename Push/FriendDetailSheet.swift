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
        return friend.placeName ?? friend.venueStatusText
    }

    /// Canonical presence activity — no View-local coffee/park/gym inventing.
    var statusLine: String {
        PresenceActivityPresentation.detailStatusLine(
            activityName: friend.activity,
            venueStatusText: friend.venueStatusText
        )
    }
}

// MARK: - Sheet Root

struct FriendDetailSheet: View {
    let puck: MapPuckData
    var onStartPush: (StartPushLaunchContext) -> Void = { _ in }
    @State private var toastMessage: String?

    private var isMultiPerson: Bool {
        switch puck.kind {
        case .hangout, .cluster, .friendGroup:
            return true
        case .individual:
            return false
        }
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
        } else if isMultiPerson {
            FriendDetailGroupContent(
                puck: puck,
                onDirections: { triggerToast("Opening in Maps…") },
                onAskToJoin: { triggerToast("Request sent") },
                onStartPush: { startPush(with: .from(puck: puck)) }
            )
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
