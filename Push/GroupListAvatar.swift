//
//  GroupListAvatar.swift
//  Push
//
//  Compact rounded-rect group avatar for list cards (Friends, Alerts, Groups).
//  Resolves bundle paths, local mock files, and live HTTPS Storage URLs via
//  AvatarImageLoader — same pipeline as profile photos.
//

import SwiftUI
import UIKit

struct GroupListAvatar: View {
    let imageAssetName: String?
    let fallbackInitials: String
    let size: CGFloat
    let cornerRadius: CGFloat
    @State private var resolvedImage: UIImage?

    var body: some View {
        ZStack {
            if let image = resolvedImage ?? AvatarImageLoader.localImage(for: imageAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        PushControlColors.activeFill.opacity(GroupListAvatarColor.fallbackTopOpacity),
                        .white.opacity(GroupListAvatarColor.fallbackBottomOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Text(fallbackInitials)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(GroupListAvatarColor.strokeOpacity), lineWidth: 1)
        }
        .task(id: imageAssetName) {
            resolvedImage = nil
            resolvedImage = await AvatarImageLoader.image(for: imageAssetName)
        }
    }
}

private enum GroupListAvatarColor {
    static let fallbackTopOpacity = 0.9
    static let fallbackBottomOpacity = 0.85
    static let strokeOpacity = 0.7
}
