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
    @State private var toastMessage: String?

    var body: some View {
        ZStack(alignment: .top) {
            if puck.kind == .individual, let friend = puck.people.first {
                individualContent(friend: friend)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        groupContent
                    }
                }
            }

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
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PushColorPalette.Accent.walnut.opacity(0.18))
                .frame(height: 0.8)
        }
        .presentationDetents(
            puck.kind == .individual
                ? [.height(FriendDetailSheetLayout.individualSheetHeight)]
                : [.medium]
        )
        .presentationDragIndicator(.visible)
        .presentationBackground {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    stops: [
                        .init(color: PushColorPalette.Accent.sunbeam.opacity(0.38), location: 0.0),
                        .init(color: PushColorPalette.Accent.sunbeam.opacity(0.08), location: 0.25),
                        .init(color: Color.clear, location: 0.45),
                        .init(color: PushColorPalette.Accent.walnut.opacity(0.08), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .presentationCornerRadius(FriendDetailSheetLayout.sheetCornerRadius)
    }

    // MARK: - Individual Layout

    private func individualContent(friend: FriendPuckData) -> some View {
        let viewData = FriendDetailViewData(friend: friend)
        return VStack(spacing: FriendDetailSheetLayout.sectionSpacing) {
            FriendDetailHeader(viewData: viewData)
            FriendActivityStatusCard(viewData: viewData)
            FriendDetailActionCards(
                onDirections: { triggerToast("Opening in Maps…") },
                onStartPlan:  { triggerToast("Plan started") }
            )
        }
        .padding(.horizontal, FriendDetailSheetLayout.contentHorizontalPadding)
        .padding(.top, FriendDetailSheetLayout.heroTopPadding)
        .padding(.bottom, FriendDetailSheetLayout.actionBottomPadding)
    }

    private func triggerToast(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                toastMessage = nil
            }
        }
    }

    // MARK: - Group Layout (unchanged)

    private var groupContent: some View {
        VStack(spacing: 0) {
            groupHero
            groupInfo
            Divider()
                .padding(.vertical, FriendDetailSheetLayout.dividerVerticalPadding)
            actionsRow(availability: puck.availability, isGroup: true)
        }
    }

    private var groupHero: some View {
        VStack(spacing: FriendDetailSheetLayout.heroNameSpacing) {
            AvatarStack(friends: puck.people, size: FriendDetailSheetLayout.heroGroupSize)
                .frame(
                    width: FriendDetailSheetLayout.heroGroupSize,
                    height: FriendDetailSheetLayout.heroGroupSize
                )

            VStack(spacing: FriendDetailSheetLayout.heroInnerSpacing) {
                Text(FriendDetailSheetContent.groupHeadline(for: puck.people))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)

                ActivityBadge(
                    text: puck.activity,
                    symbolName: puck.people.first?.activitySymbolName ?? "person.3.fill",
                    availability: puck.availability
                )
            }
        }
        .padding(.top, FriendDetailSheetLayout.heroTopPadding)
        .padding(.bottom, FriendDetailSheetLayout.heroBottomPadding)
    }

    private var groupInfo: some View {
        VStack(spacing: 0) {
            DetailInfoRow(
                symbolName: puck.people.first?.activitySymbolName ?? "mappin",
                text: puck.venueStatusText
            )
            DetailInfoRow(
                symbolName: "clock",
                text: puck.people.first?.lastUpdated ?? "Recently",
                isSecondary: true
            )
        }
        .padding(.horizontal, FriendDetailSheetLayout.infoHorizontalPadding)
    }

    private func actionsRow(availability: FriendAvailabilityState, isGroup: Bool) -> some View {
        HStack(spacing: FriendDetailSheetLayout.actionSpacing) {
            DetailActionButton(label: isGroup ? "Ping all" : "Ping", symbolName: "bolt.fill")
            DetailActionButton(label: "Start plan", symbolName: "calendar.badge.plus")
            if availability == .joinable {
                DetailActionButton(label: "Pull Up?", symbolName: "figure.wave", isPrimary: true)
            }
            DetailActionButton(label: "Hide", symbolName: "eye.slash.fill")
        }
        .padding(.horizontal, FriendDetailSheetLayout.actionHorizontalPadding)
        .padding(.bottom, FriendDetailSheetLayout.actionBottomPadding)
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
                Text(friend.availability.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(friend.availability.chipTextColor)
                    .padding(.horizontal, FriendDetailSheetLayout.headerChipHorizontalPadding)
                    .padding(.vertical, FriendDetailSheetLayout.headerChipVerticalPadding)
                    .background(friend.availability.chipFillColor, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.30), lineWidth: 0.5))

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
                label: "Start plan",
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

// MARK: - Group Sub-components (unchanged)

private struct DetailInfoRow: View {
    let symbolName: String
    let text: String
    var isSecondary: Bool = false

    var body: some View {
        HStack(spacing: FriendDetailSheetLayout.infoIconSpacing) {
            Image(systemName: symbolName)
                .font(.system(size: FriendDetailSheetLayout.infoIconSize, weight: .semibold))
                .foregroundStyle(isSecondary ? Color.secondary : PushControlColors.activeForeground)
                .frame(width: FriendDetailSheetLayout.infoIconFrameWidth)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(isSecondary ? Color.secondary : PushControlColors.activeForeground)

            Spacer()
        }
        .padding(.vertical, FriendDetailSheetLayout.infoRowVerticalPadding)
    }
}

private struct DetailActionButton: View {
    let label: String
    let symbolName: String
    var isPrimary: Bool = false

    var body: some View {
        Button(action: {}) {
            VStack(spacing: FriendDetailSheetLayout.actionLabelSpacing) {
                Image(systemName: symbolName)
                    .font(.system(size: FriendDetailSheetLayout.actionIconSize, weight: .semibold))

                Text(label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(FriendDetailSheetLayout.actionMinimumScaleFactor)
            }
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(maxWidth: .infinity)
            .frame(height: FriendDetailSheetLayout.actionHeight)
            .pushGlassBackground(cornerRadius: FriendDetailSheetLayout.actionCornerRadius)
            .overlay {
                if isPrimary {
                    RoundedRectangle(
                        cornerRadius: FriendDetailSheetLayout.actionCornerRadius,
                        style: .continuous
                    )
                    .fill(PushColorPalette.Accent.sunbeam.opacity(FriendDetailSheetLayout.primaryTintOpacity))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
