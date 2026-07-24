//
//  ProfileComponents.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI
import UIKit

struct ProfileHeader: View {
    @Environment(\.pushLayout) private var layout
    let name: String
    let handle: String
    let initials: String
    let imageAssetName: String?
    let statusTitle: String
    let statusSymbolName: String
    let editPhotoAction: () -> Void

    var body: some View {
        VStack(spacing: ProfileLayout.headerSpacing(layout)) {
            ProfileAvatar(
                initials: initials,
                imageAssetName: imageAssetName,
                action: editPhotoAction
            )
            VStack(spacing: ProfileLayout.titleSpacing) {
                Text(name)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                Text(handle)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PushControlColors.inactiveForeground)
            }
            StatusPill(title: statusTitle, symbolName: statusSymbolName)
        }
        .padding(.top, ProfileLayout.headerTopPadding(layout))
    }
}

struct ProfileBackButton: View {
    let action: () -> Void

    var body: some View {
        PushModalIconButton(
            symbolName: "arrow.left",
            accessibilityLabel: "Back",
            action: action
        )
    }
}

struct ProfileAvatar: View {
    @Environment(\.pushLayout) private var layout
    let initials: String
    let imageAssetName: String?
    let action: () -> Void
    @State private var remoteImage: UIImage?

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                avatarContent
                ProfileBadge(symbolName: "camera.fill")
                    .offset(x: ProfileLayout.cameraBadgeOffset, y: ProfileLayout.cameraBadgeOffset)
            }
            .shadow(
                color: PushColorPalette.Accent.walnut.opacity(ProfileColor.avatarShadowOpacity),
                radius: ProfileLayout.avatarShadowRadius,
                y: ProfileLayout.avatarShadowYOffset
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit profile photo")
        .task(id: imageAssetName) {
            remoteImage = nil
            remoteImage = await AvatarImageLoader.image(for: imageAssetName)
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        let size = ProfileLayout.avatarSize(layout)
        if let image = remoteImage ?? AvatarImageLoader.localImage(for: imageAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(ProfileAvatarStroke())
        } else {
            Text(initials)
                .font(.system(size: ProfileLayout.avatarTextSize(layout), weight: .bold, design: .rounded))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(width: size, height: size)
                .background(Circle().fill(PushControlColors.activeFill))
                .overlay(ProfileAvatarStroke())
        }
    }
}

private struct ProfileAvatarStroke: View {
    var body: some View {
        Circle()
            .stroke(.white.opacity(ProfileColor.avatarStrokeOpacity), lineWidth: ProfileLayout.avatarStrokeWidth)
    }
}

// StatusPill → PushBrandSunbeamPill (DesignSystem Chips).

struct ProfileRouteRow: View {
    let route: ProfileRoute

    var body: some View {
        NavigationLink(value: route) {
            ProfileRowContent(
                symbolName: route.symbolName,
                title: route.title,
                subtitle: route.subtitle,
                trailingSymbolName: "chevron.right"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(route.title)
    }
}

struct ProfileToggleRow: View {
    let item: ProfileToggleItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ProfileRowContent(
                symbolName: item.symbolName,
                title: item.title,
                subtitle: item.subtitle,
                trailingSymbolName: item.isEnabled ? "checkmark.circle.fill" : "circle"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.isEnabled ? "On" : "Off")
    }
}

struct ProfileRowContent: View {
    let symbolName: String
    let title: String
    let subtitle: String
    let trailingSymbolName: String

    var body: some View {
        HStack(spacing: ProfileLayout.rowIconSpacing) {
            StatusIcon(symbolName: symbolName)
            ProfileRowText(title: title, subtitle: subtitle)
            Spacer(minLength: 0)
            Image(systemName: trailingSymbolName)
                .font(.system(size: ProfileLayout.chevronSize, weight: .bold))
                .foregroundStyle(PushControlColors.activeForeground)
        }
        .padding(ProfileLayout.rowPadding)
        .background(ProfileRowBackground())
    }
}

struct ProfileRowText: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileLayout.rowTextSpacing) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)
            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(PushControlColors.inactiveForeground)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct StatusIcon: View {
    let symbolName: String

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: ProfileLayout.statusIconSize, weight: .bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(width: ProfileLayout.statusIconFrame, height: ProfileLayout.statusIconFrame)
            .background(Circle().fill(.white.opacity(ProfileColor.iconFillOpacity)))
    }
}

struct SectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline.weight(.bold))
            .foregroundStyle(PushControlColors.activeForeground)
    }
}

struct GlassCard<Content: View>: View {
    @Environment(\.pushLayout) private var layout
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(ProfileLayout.cardPadding(layout))
            .pushGlassBackground(cornerRadius: ProfileLayout.cardCornerRadius(layout))
    }
}

private struct ProfileBadge: View {
    @Environment(\.pushLayout) private var layout
    let symbolName: String

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: ProfileLayout.cameraBadgeIconSize, weight: .bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(width: ProfileLayout.cameraBadgeSize(layout), height: ProfileLayout.cameraBadgeSize(layout))
            .background(Circle().fill(.white.opacity(ProfileColor.cameraBadgeFillOpacity)))
            .overlay {
                Circle()
                    .stroke(PushControlColors.activeFill, lineWidth: ProfileLayout.cameraBadgeStrokeWidth)
            }
    }
}

private struct ProfileRowBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: ProfileLayout.rowCornerRadius, style: .continuous)
            .fill(.white.opacity(ProfileColor.rowFillOpacity))
    }
}
