//
//  PushPersonAvatar.swift
//  Push
//
//  DS-050 — canonical circular person avatar with dark vs sunbeam fallbacks.
//

import SwiftUI
import UIKit

/// Initials fallback treatment when no photo is available.
enum PushPersonAvatarFallbackStyle {
    /// Dark plum gradient — lists, map pucks, cream cards.
    case dark
    /// Sunbeam fill + walnut initials — modal multi-select / Start Push.
    case sunbeam
}

/// One circular person face for all person identity surfaces.
struct PushPersonAvatar: View {
    let imageAssetName: String?
    let fallbackInitials: String
    var fallbackStyle: PushPersonAvatarFallbackStyle = .dark
    /// When non-nil, fixed frame (RecipientAvatarView style). GeometryReader used when nil.
    var size: CGFloat? = nil
    @State private var remoteImage: UIImage?

    var body: some View {
        Group {
            if let size {
                fixedSizeContent(size: size)
            } else {
                geometryContent
            }
        }
        .task(id: imageAssetName) {
            remoteImage = nil
            remoteImage = await AvatarImageLoader.image(for: imageAssetName)
        }
    }

    private var geometryContent: some View {
        GeometryReader { proxy in
            avatarContent(side: proxy.size.width)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(Circle())
    }

    private func fixedSizeContent(size: CGFloat) -> some View {
        avatarContent(side: size)
            .frame(width: size, height: size)
            .clipShape(Circle())
    }

    @ViewBuilder
    private func avatarContent(side: CGFloat) -> some View {
        if let image = displayImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Text(fallbackInitials)
                .font(.system(
                    size: side * initialsScale,
                    weight: .bold,
                    design: .rounded
                ))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(fallbackForeground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    Circle().fill(fallbackBackground)
                }
        }
    }

    private var displayImage: UIImage? {
        remoteImage ?? AvatarImageLoader.localImage(for: imageAssetName)
    }

    private var initialsScale: CGFloat {
        switch fallbackStyle {
        case .dark: return FriendPuckLayout.initialsScale
        case .sunbeam: return 0.32
        }
    }

    private var fallbackForeground: Color {
        switch fallbackStyle {
        case .dark: return PushAvailabilityTokens.avatarForeground
        case .sunbeam: return PushControlColors.activeForeground
        }
    }

    private var fallbackBackground: Color {
        switch fallbackStyle {
        case .dark: return PushAvailabilityTokens.avatarGradientBase
        case .sunbeam: return PushControlColors.activeFill
        }
    }
}

/// Migration shim — dark fallback person avatar (list/map default).
struct ProfilePhotoAvatar: View {
    let imageAssetName: String?
    let fallbackInitials: String

    var body: some View {
        PushPersonAvatar(
            imageAssetName: imageAssetName,
            fallbackInitials: fallbackInitials,
            fallbackStyle: .dark
        )
    }
}

/// Migration shim — sunbeam fallback for Start Push modal rows.
struct RecipientAvatarView: View {
    let imageAssetName: String?
    let initials: String
    let size: CGFloat

    var body: some View {
        PushPersonAvatar(
            imageAssetName: imageAssetName,
            fallbackInitials: initials,
            fallbackStyle: .sunbeam,
            size: size
        )
    }
}

#if DEBUG
struct PushPersonAvatar_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            HStack(spacing: 16) {
                PushPersonAvatar(
                    imageAssetName: nil,
                    fallbackInitials: "AK",
                    fallbackStyle: .dark,
                    size: 48
                )
                PushPersonAvatar(
                    imageAssetName: nil,
                    fallbackInitials: "AK",
                    fallbackStyle: .sunbeam,
                    size: 48
                )
            }
            .padding()
            .background(PushIvoryPageBackground())
        }
    }
}
#endif
