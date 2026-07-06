//
//  AvatarStack.swift
//  Push
//

import SwiftUI

struct AvatarStack: View {
    let friends: [FriendPuckData]
    let size: CGFloat

    private var displayedFriends: [FriendPuckData] {
        Array(friends.prefix(AvatarStackLayout.visibleAvatarLimit))
    }

    var body: some View {
        ZStack {
            ForEach(Array(displayedFriends.enumerated()), id: \.element.id) { index, friend in
                ProfilePhotoAvatar(
                    imageAssetName: friend.profileImageAssetName,
                    fallbackInitials: friend.avatarPlaceholder
                )
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(AvatarStackLayout.avatarStrokeOpacity), lineWidth: AvatarStackLayout.avatarStrokeWidth)
                    }
                    .offset(offset(for: index))
            }
        }
    }

    private var avatarSize: CGFloat {
        size * AvatarStackLayout.avatarScale
    }

    private func offset(for index: Int) -> CGSize {
        let offsets = AvatarStackLayout.offsets
        guard offsets.indices.contains(index) else {
            return .zero
        }
        return CGSize(
            width: offsets[index].width * size,
            height: offsets[index].height * size
        )
    }
}

private enum AvatarStackLayout {
    static let visibleAvatarLimit = 3
    static let avatarScale = 0.58
    static let initialsScale = 0.14
    static let avatarStrokeOpacity = 0.86
    static let avatarStrokeWidth: CGFloat = 1.4
    static let offsets: [CGSize] = [
        CGSize(width: -0.16, height: -0.11),
        CGSize(width: 0.18, height: -0.04),
        CGSize(width: 0.02, height: 0.2)
    ]
}
