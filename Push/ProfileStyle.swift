//
//  ProfileStyle.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI

enum ProfileLayout {
    static func horizontalPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.pageHorizontalPadding }
    static let topPadding: CGFloat = 18
    static let bottomPadding: CGFloat = 88
    static let closeTopPadding: CGFloat = 16
    static let closeBottomPadding: CGFloat = 12
    static let closeButtonSize: CGFloat = 44
    static let closeIconSize: CGFloat = 14
    static func sectionSpacing(_ layout: PushAdaptiveLayout) -> CGFloat { layout.sectionSpacing }
    static func headerSpacing(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 10, standard: 12, large: 14) }
    static func headerTopPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 2, standard: 5, large: 8) }
    static let titleSpacing: CGFloat = 3
    static let summaryHorizontalPadding: CGFloat = 18
    static func avatarSize(_ layout: PushAdaptiveLayout) -> CGFloat { layout.avatarLarge }
    static func avatarTextSize(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 30, standard: 32, large: 34) }
    static let avatarStrokeWidth: CGFloat = 1.2
    static let avatarShadowRadius: CGFloat = 18
    static let avatarShadowYOffset: CGFloat = 8
    static func cameraBadgeSize(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 30, standard: 32, large: 34) }
    static let cameraBadgeIconSize: CGFloat = 14
    static let cameraBadgeStrokeWidth: CGFloat = 2
    static let cameraBadgeOffset: CGFloat = 4
    static let pillSpacing: CGFloat = 7
    static let pillIconSize: CGFloat = 13
    static let pillHorizontalPadding: CGFloat = 14
    static let pillVerticalPadding: CGFloat = 8
    static func cardPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.cardPadding }
    static func cardCornerRadius(_ layout: PushAdaptiveLayout) -> CGFloat { layout.cardCornerRadius }
    static let statusIconSize: CGFloat = 15
    static let statusIconFrame: CGFloat = 34
    static let rowSpacing: CGFloat = 8
    static let rowIconSpacing: CGFloat = 12
    static let rowPadding: CGFloat = 12
    static let rowCornerRadius: CGFloat = 18
    static let rowTextSpacing: CGFloat = 3
    static let selectionIconSize: CGFloat = 20
    static let chevronSize: CGFloat = 12
    static let connectorButtonSpacing: CGFloat = 10
    static let fieldSpacing: CGFloat = 12
    static let fieldCornerRadius: CGFloat = 16
    static let fieldPadding: CGFloat = 12
    static let selectionAnimationResponse = 0.24
    static let selectionAnimationDamping = 0.88
}

enum ProfileColor {
    static let sunbeamTopOpacity = 0.62
    static let walnutBottomOpacity = 0.18
    static let avatarStrokeOpacity = 0.82
    static let avatarShadowOpacity = 0.18
    static let cameraBadgeFillOpacity = 0.9
    static let rowFillOpacity = 0.28
    static let iconFillOpacity = 0.38
}

// PushModalBackground lives in DesignSystem/Surfaces/PushModalSurface.swift (DS-015).

struct PushModalCloseButtonBar: View {
    @Environment(\.pushLayout) private var layout
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            PushCircleIconButton(
                systemImageName: "xmark",
                accessibilityLabel: accessibilityLabel,
                action: action
            )
        }
        .padding(.horizontal, ProfileLayout.horizontalPadding(layout))
        .padding(.top, ProfileLayout.closeTopPadding)
        .padding(.bottom, ProfileLayout.closeBottomPadding)
    }
}

/// Migration shim mapping `symbolName` → `PushCircleIconButton` (DS-001).
struct PushModalIconButton: View {
    let symbolName: String
    let accessibilityLabel: String
    var foreground: Color = PushControlColors.activeForeground
    let action: () -> Void

    var body: some View {
        PushCircleIconButton(
            systemImageName: symbolName,
            accessibilityLabel: accessibilityLabel,
            foreground: foreground,
            action: action
        )
    }
}
