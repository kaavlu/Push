//
//  PushExpandableActionRail.swift
//  Push
//
//  DS-008 / DS-065 — configurable expandable row action rail.
//

import SwiftUI

/// One primary action on the expandable rail (Directions, Start push, …).
struct PushExpandableRailAction: Identifiable {
    let id: String
    let label: String
    let systemImageName: String
    let action: () -> Void

    init(
        id: String? = nil,
        label: String,
        systemImageName: String,
        action: @escaping () -> Void
    ) {
        self.id = id ?? label
        self.label = label
        self.systemImageName = systemImageName
        self.action = action
    }
}

enum PushExpandableActionRailMetrics {
    static let actionsTopSpacing: CGFloat = 6
    static let railBottomPadding: CGFloat = 10
    static let railSpacing: CGFloat = 8
    static let railHeight: CGFloat = 40
    static let railCornerRadius: CGFloat = 12
    static let actionIconSize: CGFloat = 13
    static let actionLabelSpacing: CGFloat = 4
    static let overflowWidth: CGFloat = 40
    static let overflowIconSize: CGFloat = 15
    static let railBorderWidth: CGFloat = 1.5
    static let railBorderOpacity = 0.40
}

/// Horizontal action rail under an expanded person row. Primary actions share
/// width; optional overflow slot (menu) stays fixed width.
struct PushExpandableActionRail<Overflow: View>: View {
    let actions: [PushExpandableRailAction]
    var isBusy: Bool = false
    @ViewBuilder var overflow: () -> Overflow

    var body: some View {
        HStack(spacing: PushExpandableActionRailMetrics.railSpacing) {
            ForEach(actions) { item in
                PushExpandableRailActionButton(
                    label: item.label,
                    systemImageName: item.systemImageName,
                    action: item.action
                )
            }
            overflow()
        }
        .frame(height: PushExpandableActionRailMetrics.railHeight)
    }
}

extension PushExpandableActionRail where Overflow == EmptyView {
    init(actions: [PushExpandableRailAction], isBusy: Bool = false) {
        self.actions = actions
        self.isBusy = isBusy
        self.overflow = { EmptyView() }
    }
}

/// Uniform primary control — equal share of remaining rail width after overflow.
struct PushExpandableRailActionButton: View {
    let label: String
    let systemImageName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PushExpandableActionRailMetrics.actionLabelSpacing) {
                Image(systemName: systemImageName)
                    .font(.system(
                        size: PushExpandableActionRailMetrics.actionIconSize,
                        weight: .semibold
                    ))
                Text(label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(PushOpacityTokens.minimumTextScale)
            }
            .foregroundStyle(PushControlColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: PushExpandableActionRailMetrics.railHeight)
            .pushExpandableRailSurface()
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
    }
}

/// Overflow control chrome matching rail actions (content supplied by caller).
struct PushExpandableRailOverflowChrome<Content: View>: View {
    var isBusy: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .tint(PushControlColors.textSecondary)
            } else {
                content()
            }
        }
        .frame(
            width: PushExpandableActionRailMetrics.overflowWidth,
            height: PushExpandableActionRailMetrics.railHeight
        )
        .contentShape(RoundedRectangle(
            cornerRadius: PushExpandableActionRailMetrics.railCornerRadius,
            style: .continuous
        ))
        .pushExpandableRailSurface()
    }
}

/// Ellipsis glyph used inside overflow chrome — same weight/color as rail actions.
struct PushExpandableRailOverflowGlyph: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(
                size: PushExpandableActionRailMetrics.overflowIconSize,
                weight: .semibold
            ))
            .foregroundStyle(PushControlColors.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }
}

/// Overflow menu whose label matches primary rail action chrome (not system Menu chrome).
struct PushExpandableRailOverflowMenu<MenuContent: View>: View {
    var isBusy: Bool = false
    let accessibilityLabel: String
    var accessibilityHint: String? = nil
    @ViewBuilder var menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            PushExpandableRailOverflowChrome(isBusy: isBusy) {
                PushExpandableRailOverflowGlyph()
            }
        }
        .buttonStyle(.plain)
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .disabled(isBusy)
        .accessibilityLabel(accessibilityLabel)
        .modifier(OptionalAccessibilityHint(hint: accessibilityHint))
    }
}

private struct OptionalAccessibilityHint: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint, !hint.isEmpty {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

extension View {
    /// Flat cream fill + thin walnut rim — flush on the parent solid cream card.
    func pushExpandableRailSurface() -> some View {
        let shape = RoundedRectangle(
            cornerRadius: PushExpandableActionRailMetrics.railCornerRadius,
            style: .continuous
        )
        return background(shape.fill(PushCreamTokens.pageIvory))
            .overlay {
                shape.stroke(
                    PushColorPalette.Accent.walnut.opacity(
                        PushExpandableActionRailMetrics.railBorderOpacity
                    ),
                    lineWidth: PushExpandableActionRailMetrics.railBorderWidth
                )
            }
    }
}

#if DEBUG
struct PushExpandableActionRail_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            PushExpandableActionRail(
                actions: [
                    PushExpandableRailAction(
                        label: "Directions",
                        systemImageName: "arrow.triangle.turn.up.right.circle.fill",
                        action: {}
                    ),
                    PushExpandableRailAction(
                        label: "Start push",
                        systemImageName: "calendar.badge.plus",
                        action: {}
                    )
                ]
            ) {
                PushExpandableRailOverflowMenu(
                    accessibilityLabel: "More actions",
                    accessibilityHint: "Remove friend or block"
                ) {
                    Button("Remove friend", role: .destructive) {}
                    Button("Block", role: .destructive) {}
                }
            }
            .padding()
            .pushSolidCreamCard(cornerRadius: 20)
            .padding()
            .background(PushIvoryPageBackground())
        }
    }
}
#endif
