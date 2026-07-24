//
//  PushListSectionHeader.swift
//  Push
//
//  DS-034 — shared section header for ivory list screens (Alerts, Friends, …).
//

import SwiftUI

/// Uppercased section title + optional count badge for cream list screens.
struct PushListSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: FriendsLayout.sectionHeaderSpacing) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .kerning(FriendsLayout.sectionHeaderKerning)
                .foregroundStyle(PushControlColors.textTertiary)

            Text("\(count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(PushControlColors.textSecondary)
                .padding(.horizontal, FriendsLayout.sectionCountHorizontalPadding)
                .padding(.vertical, FriendsLayout.sectionCountVerticalPadding)
                .background(
                    Capsule().fill(
                        PushColorPalette.Accent.walnut.opacity(FriendsColor.sectionBadgeFillOpacity)
                    )
                )

            Spacer(minLength: 0)
        }
        .padding(.bottom, FriendsLayout.sectionHeaderBottomPadding)
    }
}

/// Migration shim — prefer `PushListSectionHeader`.
typealias FriendsSectionHeader = PushListSectionHeader

#if DEBUG
struct PushListSectionHeader_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            PushListSectionHeader(title: "Friend Requests", count: 3)
                .padding()
                .background(PushIvoryPageBackground())
        }
    }
}
#endif
