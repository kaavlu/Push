import SwiftUI

/// Alert-only geometry and motion. Spacing, card chrome, and horizontal margins
/// reuse `FriendsLayout` / `FriendsColor` so the page matches Friends.
enum AlertsLayout {
    /// Extra gap under the page subtitle before the section header / empty state.
    static let contentTopSpacing: CGFloat = 6
    /// Gap between the Friend Requests and Group Requests sections.
    static let sectionTopSpacing: CGFloat = 18
    static let actionSegmentWidth: CGFloat = 38
    static let actionCapsuleHeight: CGFloat = 38
    static let actionIconSize: CGFloat = 13
    static let actionDividerHeight: CGFloat = 18
    static let actionHorizontalPadding: CGFloat = 12
    static let actionVerticalPadding: CGFloat = 7
    static let actionStrokeWidth: CGFloat = 0.9
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
    static let actionStrokeOpacity = 0.22
    static let actionFillOpacity = 0.52
    static let actionDividerOpacity = 0.18
    static let disabledOpacity = 0.55
    static let addedFillOpacity = 0.88
}

/// Which action an `AlertActionButton` renders — shared by friend-request and
/// group-invite cards so accept/deny always look and feel identical.
enum AlertActionStyle {
    case accept
    case deny
}

/// Compact request action system shared by friend and group request cards.
/// The actions stay independently accessible while reading as one segmented
/// capsule in the row.
struct AlertRequestActionCapsule: View {
    let disabled: Bool
    let denyAccessibilityLabel: String
    let acceptAccessibilityLabel: String
    let onDeny: () -> Void
    let onAccept: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            AlertActionButton(
                systemImageName: "xmark",
                style: .deny,
                accessibilityLabel: denyAccessibilityLabel,
                action: onDeny
            )

            Rectangle()
                .fill(
                    PushColorPalette.Accent.walnut
                        .opacity(AlertsColor.actionDividerOpacity)
                )
                .frame(width: AlertsLayout.actionStrokeWidth)
                .frame(height: AlertsLayout.actionDividerHeight)

            AlertActionButton(
                systemImageName: "checkmark",
                style: .accept,
                accessibilityLabel: acceptAccessibilityLabel,
                action: onAccept
            )
        }
        .frame(height: AlertsLayout.actionCapsuleHeight)
        .background(
            PushCreamTokens.pageIvory.opacity(AlertsColor.actionFillOpacity),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(
                    PushColorPalette.Accent.walnut
                        .opacity(AlertsColor.actionStrokeOpacity),
                    lineWidth: AlertsLayout.actionStrokeWidth
                )
        }
        .clipShape(Capsule())
        .disabled(disabled)
        .opacity(disabled ? AlertsColor.disabledOpacity : 1)
    }
}

/// One independently accessible segment inside `AlertRequestActionCapsule`.
struct AlertActionButton: View {
    let systemImageName: String
    let style: AlertActionStyle
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImageName)
                .font(.system(size: AlertsLayout.actionIconSize, weight: .bold))
                .foregroundStyle(foregroundColor)
                .frame(
                    width: AlertsLayout.actionSegmentWidth,
                    height: AlertsLayout.actionCapsuleHeight
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var foregroundColor: Color {
        switch style {
        case .accept: return PushControlColors.activeForeground
        case .deny: return PushControlColors.textSecondary
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
