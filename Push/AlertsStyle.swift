import SwiftUI

/// Alert-only geometry and motion. Spacing, card chrome, and horizontal margins
/// reuse `FriendsLayout` / `FriendsColor` so the page matches Friends.
enum AlertsLayout {
    /// Extra gap under the page subtitle before the section header / empty state.
    static let contentTopSpacing: CGFloat = 6
    /// Gap between the Friend Requests and Group Requests sections.
    static let sectionTopSpacing: CGFloat = 18
    static let actionSpacing: CGFloat = 8
    static let actionHorizontalPadding: CGFloat = 12
    static let actionVerticalPadding: CGFloat = 7
    static let actionStrokeWidth: CGFloat = 0.9
    static let actionMinWidth: CGFloat = 58
    static let stateSpacing: CGFloat = 10
    static let stateIconSize: CGFloat = 28
    static let stateHorizontalPadding: CGFloat = 36
    /// Brief hold on the "Added" pill before the card leaves.
    static let addedHoldNanoseconds: UInt64 = 700_000_000
    /// Matches the deny fade/collapse animation duration.
    static let denyCollapseNanoseconds: UInt64 = 280_000_000
    static let denyCollapseDuration: Double = 0.28
    static let addedTransitionDuration: Double = 0.22
    static let removeDuration: Double = 0.32
}

enum AlertsColor {
    static let denyStrokeOpacity = 0.22
    static let denyFillOpacity = 0.42
    static let disabledOpacity = 0.55
    static let addedFillOpacity = 0.88
}

/// Which action an `AlertActionButton` renders — shared by friend-request and
/// group-invite cards so accept/deny always look and feel identical.
enum AlertActionStyle {
    case accept
    case deny
}

/// Extracted from `AlertsView` so `GroupRequestCard` renders pixel-identical
/// accept/deny capsules without duplicating the styling constants.
struct AlertActionButton: View {
    let title: String
    let style: AlertActionStyle
    let disabled: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(minWidth: AlertsLayout.actionMinWidth)
                .padding(.horizontal, AlertsLayout.actionHorizontalPadding)
                .padding(.vertical, AlertsLayout.actionVerticalPadding)
                .background(backgroundFill, in: Capsule())
                .overlay {
                    if style == .deny {
                        Capsule().stroke(
                            PushColorPalette.Accent.walnut.opacity(AlertsColor.denyStrokeOpacity),
                            lineWidth: AlertsLayout.actionStrokeWidth
                        )
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? AlertsColor.disabledOpacity : 1)
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundFill: Color {
        switch style {
        case .accept: return PushControlColors.activeFill
        case .deny: return FriendsColor.cardCream.opacity(AlertsColor.denyFillOpacity)
        }
    }
}

/// The post-accept "Added" pill, shown in place of the accept/deny pair
/// while the card briefly holds before leaving the list.
struct AlertAddedBadge: View {
    var body: some View {
        Text(AlertsCopy.addedLabel)
            .font(.caption.weight(.bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .padding(.horizontal, AlertsLayout.actionHorizontalPadding)
            .padding(.vertical, AlertsLayout.actionVerticalPadding)
            .background(
                PushColorPalette.Accent.mintFoam.opacity(AlertsColor.addedFillOpacity),
                in: Capsule()
            )
            .accessibilityLabel(AlertsCopy.addedLabel)
    }
}
