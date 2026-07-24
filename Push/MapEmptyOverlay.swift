//
//  MapEmptyOverlay.swift
//  Push
//
//  Compact non-blocking empty/failed card for the live map. Sits above the
//  satellite base without covering profile, filter, bell, or bottom nav.
//

import SwiftUI

struct MapEmptyOverlay: View {
    let phase: SurfaceContentPhase
    var onAddFriends: (() -> Void)? = nil
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: MapEmptyOverlayLayout.contentSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: MapEmptyOverlayLayout.iconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textSecondary)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                PushSolidSunbeamButton(title: actionTitle, action: action)
                    .padding(.top, MapEmptyOverlayLayout.actionTopPadding)
            }
        }
        .padding(.horizontal, MapEmptyOverlayLayout.cardHorizontalPadding)
        .padding(.vertical, MapEmptyOverlayLayout.cardVerticalPadding)
        .frame(maxWidth: MapEmptyOverlayLayout.maxCardWidth)
        .pushGlassBackground(cornerRadius: MapEmptyOverlayLayout.cornerRadius)
        .accessibilityElement(children: .combine)
    }

    private var systemImage: String {
        phase == .failed ? "exclamationmark.triangle" : "person.2"
    }

    private var title: String {
        phase == .failed
            ? EmptySurfaceCopy.failedTitle(surface: "map")
            : EmptySurfaceCopy.mapEmptyTitle
    }

    private var message: String {
        phase == .failed
            ? EmptySurfaceCopy.failedMessage
            : EmptySurfaceCopy.mapEmptyMessage
    }

    private var actionTitle: String? {
        switch phase {
        case .empty:
            return onAddFriends == nil ? nil : EmptySurfaceCopy.addFriendsAction
        case .failed:
            return onRetry == nil ? nil : EmptySurfaceCopy.retryAction
        default:
            return nil
        }
    }

    private var action: (() -> Void)? {
        switch phase {
        case .empty: return onAddFriends
        case .failed: return onRetry
        default: return nil
        }
    }
}

enum MapEmptyOverlayLayout {
    static let contentSpacing: CGFloat = 10
    static let iconSize: CGFloat = 28
    static let actionTopPadding: CGFloat = 12
    static let cardHorizontalPadding: CGFloat = 20
    static let cardVerticalPadding: CGFloat = 18
    static let maxCardWidth: CGFloat = 320
    static let cornerRadius: CGFloat = 22
    static let horizontalPadding: CGFloat = 28
    /// Clears bottom nav + create button so the card sits in lower-middle map.
    static func bottomClearance(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.value(compact: 108, standard: 116, large: 124)
    }
}
