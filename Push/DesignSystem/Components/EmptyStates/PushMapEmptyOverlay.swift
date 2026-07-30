//
//  PushMapEmptyOverlay.swift
//  Push
//
//  DS-072 — map empty/failed control-glass overlay (not full-page cream empty).
//

import SwiftUI

/// Compact non-blocking empty/failed card for the live map. Sits above the
/// satellite base without covering profile, filter, bell, or bottom nav.
struct MapEmptyOverlay: View {
    let phase: SurfaceContentPhase
    var onAddFriends: (() -> Void)? = nil
    /// Empty-phase only — top-leading dismiss; hides the card for good.
    var onDismissEmpty: (() -> Void)? = nil
    var onRetry: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
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
            // Keep title clear of the top-leading dismiss control.
            .padding(.top, showsDismissButton ? MapEmptyOverlayLayout.dismissClearance : 0)
            .frame(maxWidth: MapEmptyOverlayLayout.maxCardWidth)

            if showsDismissButton, let onDismissEmpty {
                Button(action: onDismissEmpty) {
                    Image(systemName: "xmark")
                        .font(.system(
                            size: MapEmptyOverlayLayout.dismissIconSize,
                            weight: .bold
                        ))
                        .foregroundStyle(PushControlColors.textSecondary)
                        .frame(
                            width: MapEmptyOverlayLayout.dismissHitSize,
                            height: MapEmptyOverlayLayout.dismissHitSize
                        )
                        .background(
                            Circle()
                                .fill(Color.white.opacity(MapEmptyOverlayLayout.dismissFillOpacity))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, MapEmptyOverlayLayout.dismissPadding)
                .padding(.leading, MapEmptyOverlayLayout.dismissPadding)
                .accessibilityLabel("Dismiss")
            }
        }
        .pushGlassBackground(cornerRadius: MapEmptyOverlayLayout.cornerRadius)
        .accessibilityElement(children: .contain)
    }

    private var showsDismissButton: Bool {
        phase == .empty && onDismissEmpty != nil
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
    static let dismissIconSize: CGFloat = 11
    static let dismissHitSize: CGFloat = 28
    static let dismissPadding: CGFloat = 10
    static let dismissClearance: CGFloat = 8
    static let dismissFillOpacity = 0.55
    /// Clears bottom nav + create button so the card sits in lower-middle map.
    static func bottomClearance(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.value(compact: 108, standard: 116, large: 124)
    }
}

#if DEBUG
struct PushMapEmptyOverlay_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            ZStack {
                Color.gray.opacity(0.4)
                MapEmptyOverlay(phase: .empty, onAddFriends: {}, onDismissEmpty: {})
            }
        }
    }
}
#endif
