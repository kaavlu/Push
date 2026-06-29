//
//  ActivityBadge.swift
//  Push
//

import SwiftUI

struct ActivityBadge: View {
    let text: String
    let symbolName: String
    let availability: FriendAvailabilityState

    var body: some View {
        HStack(spacing: ActivityBadgeLayout.spacing) {
            Image(systemName: symbolName)
                .font(.system(size: ActivityBadgeLayout.iconSize, weight: .bold))

            Text(text)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(PuckColorTokens.badgeForeground)
        .padding(.horizontal, ActivityBadgeLayout.horizontalPadding)
        .padding(.vertical, ActivityBadgeLayout.verticalPadding)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .background {
                    Capsule()
                        .fill(availability.accentColor.opacity(ActivityBadgeLayout.tintOpacity))
                }
        }
        .overlay {
            Capsule()
                .stroke(.white.opacity(ActivityBadgeLayout.strokeOpacity), lineWidth: ActivityBadgeLayout.strokeWidth)
        }
    }
}

private enum ActivityBadgeLayout {
    static let spacing: CGFloat = 4
    static let iconSize: CGFloat = 9
    static let horizontalPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 5
    static let tintOpacity = 0.48
    static let strokeOpacity = 0.7
    static let strokeWidth: CGFloat = 0.8
}
