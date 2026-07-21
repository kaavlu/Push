//
//  GroupPhotoBadge.swift
//  Push
//
//  The large editable group photo treatment (rounded hero image + camera
//  badge), extracted from GroupDetailView so the Add Group flow can reuse
//  the exact same visual language while a photo is only picked, not yet
//  persisted — see `overrideImage`.
//
//  Persisted paths may be bundle assets (mock seed), local file paths (mock
//  upload), or HTTPS Storage URLs (live). Resolve via AvatarImageLoader —
//  never PushImageAssets alone, or live photos never appear after upload.
//

import SwiftUI
import UIKit

struct GroupPhotoBadge: View {
    let imageAssetName: String?
    let fallbackInitials: String
    /// In-flight / session override (picked image while upload runs, or local preview).
    let overrideImage: UIImage?
    @State private var resolvedImage: UIImage?

    init(imageAssetName: String?, fallbackInitials: String, overrideImage: UIImage? = nil) {
        self.imageAssetName = imageAssetName
        self.fallbackInitials = fallbackInitials
        self.overrideImage = overrideImage
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            photo
                .frame(width: GroupPhotoBadgeLayout.heroImageSize, height: GroupPhotoBadgeLayout.heroImageSize)
                .clipShape(RoundedRectangle(cornerRadius: GroupPhotoBadgeLayout.heroImageCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: GroupPhotoBadgeLayout.heroImageCornerRadius, style: .continuous)
                        .stroke(
                            .white.opacity(GroupPhotoBadgeColor.imageStrokeOpacity),
                            lineWidth: GroupPhotoBadgeLayout.imageStrokeWidth
                        )
                }

            GroupPhotoBadgeEditGlyph()
                .offset(x: GroupPhotoBadgeLayout.editBadgeOffset, y: GroupPhotoBadgeLayout.editBadgeOffset)
        }
        .shadow(
            color: PushColorPalette.Accent.walnut.opacity(GroupPhotoBadgeColor.imageShadowOpacity),
            radius: GroupPhotoBadgeLayout.imageShadowRadius,
            y: GroupPhotoBadgeLayout.imageShadowYOffset
        )
        .task(id: imageAssetName) {
            resolvedImage = nil
            resolvedImage = await AvatarImageLoader.image(for: imageAssetName)
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let overrideImage {
            Image(uiImage: overrideImage)
                .resizable()
                .scaledToFill()
        } else if let image = resolvedImage ?? AvatarImageLoader.localImage(for: imageAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            GroupPhotoBadgeFallbackTile(initials: fallbackInitials)
        }
    }
}

/// Purely decorative in GroupDetailView; the create-flow makes it tappable by
/// wrapping the whole `GroupPhotoBadge` in a `PhotosPicker` label at the call site.
private struct GroupPhotoBadgeEditGlyph: View {
    var body: some View {
        Image(systemName: "camera.fill")
            .font(.system(size: GroupPhotoBadgeLayout.editBadgeIconSize, weight: .bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(width: GroupPhotoBadgeLayout.editBadgeSize, height: GroupPhotoBadgeLayout.editBadgeSize)
            .background(Circle().fill(.white.opacity(GroupPhotoBadgeColor.editBadgeFillOpacity)))
            .overlay {
                Circle()
                    .stroke(PushControlColors.activeFill, lineWidth: GroupPhotoBadgeLayout.editBadgeStrokeWidth)
            }
    }
}

private struct GroupPhotoBadgeFallbackTile: View {
    let initials: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PushControlColors.activeFill.opacity(GroupPhotoBadgeColor.fallbackTopOpacity),
                    .white.opacity(GroupPhotoBadgeColor.fallbackBottomOpacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(initials)
                .font(.system(size: GroupPhotoBadgeLayout.fallbackTextSize, weight: .bold, design: .rounded))
                .foregroundStyle(PushControlColors.activeForeground)
        }
    }
}

enum GroupPhotoBadgeLayout {
    static let heroImageSize: CGFloat = 112
    static let heroImageCornerRadius: CGFloat = 34
    static let imageStrokeWidth: CGFloat = 1.2
    static let imageShadowRadius: CGFloat = 18
    static let imageShadowYOffset: CGFloat = 8
    static let fallbackTextSize: CGFloat = 34
    static let editBadgeSize: CGFloat = 34
    static let editBadgeIconSize: CGFloat = 14
    static let editBadgeStrokeWidth: CGFloat = 2
    static let editBadgeOffset: CGFloat = 4
}

enum GroupPhotoBadgeColor {
    static let imageStrokeOpacity = 0.82
    static let imageShadowOpacity = 0.18
    static let fallbackTopOpacity = 0.92
    static let fallbackBottomOpacity = 0.86
    static let editBadgeFillOpacity = 0.9
}
