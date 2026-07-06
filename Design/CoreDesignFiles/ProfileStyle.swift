//
//  ProfileStyle.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI

enum ProfileLayout {
    static let horizontalPadding: CGFloat = 18
    static let topPadding: CGFloat = 18
    static let bottomPadding: CGFloat = 88
    static let closeTopPadding: CGFloat = 16
    static let closeBottomPadding: CGFloat = 12
    static let closeButtonSize: CGFloat = 44
    static let closeIconSize: CGFloat = 14
    static let backIconSize: CGFloat = 13
    static let backButtonSpacing: CGFloat = 6
    static let backHorizontalPadding: CGFloat = 14
    static let sectionSpacing: CGFloat = 18
    static let headerSpacing: CGFloat = 14
    static let headerTopPadding: CGFloat = 8
    static let titleSpacing: CGFloat = 3
    static let summaryHorizontalPadding: CGFloat = 18
    static let avatarSize: CGFloat = 112
    static let avatarTextSize: CGFloat = 34
    static let avatarStrokeWidth: CGFloat = 1.2
    static let avatarShadowRadius: CGFloat = 18
    static let avatarShadowYOffset: CGFloat = 8
    static let cameraBadgeSize: CGFloat = 34
    static let cameraBadgeIconSize: CGFloat = 14
    static let cameraBadgeStrokeWidth: CGFloat = 2
    static let cameraBadgeOffset: CGFloat = 4
    static let pillSpacing: CGFloat = 7
    static let pillIconSize: CGFloat = 13
    static let pillHorizontalPadding: CGFloat = 14
    static let pillVerticalPadding: CGFloat = 8
    static let cardPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 26
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

struct PushModalBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                PushColorPalette.Accent.sunbeam.opacity(ProfileColor.sunbeamTopOpacity),
                .white,
                PushColorPalette.Accent.walnut.opacity(ProfileColor.walnutBottomOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct PushModalCloseButtonBar: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            PushModalCloseButton(
                accessibilityLabel: accessibilityLabel,
                action: action
            )
        }
        .padding(.horizontal, ProfileLayout.horizontalPadding)
        .padding(.top, ProfileLayout.closeTopPadding)
        .padding(.bottom, ProfileLayout.closeBottomPadding)
    }
}

private struct PushModalCloseButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: ProfileLayout.closeIconSize, weight: .bold))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(width: ProfileLayout.closeButtonSize, height: ProfileLayout.closeButtonSize)
                .pushGlassBackground(cornerRadius: ProfileLayout.closeButtonSize / 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
