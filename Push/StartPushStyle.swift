//
//  StartPushStyle.swift
//  Push
//
//  Created by Manav Khanvilkar on 7/1/26.
//

import SwiftUI

enum StartPushLayout {
    static let horizontalPadding: CGFloat = 20
    static let stepCount = 4
    static let dotSize: CGFloat = 8
    static let dotActiveWidth: CGFloat = 32
    static let dotActiveHeight: CGFloat = 24
    static let dotSpacing: CGFloat = 10
    static let headerSpacing: CGFloat = 6
    static let sectionSpacing: CGFloat = 22
    static let cardCornerRadius: CGFloat = 22
    static let cardPadding: CGFloat = 16
    static let chipHorizontalPadding: CGFloat = 14
    static let chipVerticalPadding: CGFloat = 7
    static let pillCornerRadius: CGFloat = 22
    static let pillHorizontalPadding: CGFloat = 16
    static let pillVerticalPadding: CGFloat = 10
    static let groupCardWidth: CGFloat = 108
    static let groupCardHeight: CGFloat = 94
    static let groupAvatarSize: CGFloat = 46
    static let searchBarHeight: CGFloat = 44
    static let searchIconSize: CGFloat = 14
    static let primaryButtonHeight: CGFloat = 54
    static let closeButtonSize: CGFloat = 44
    static let closeIconSize: CGFloat = 14
    static let backIconSize: CGFloat = 13
    static let backHorizontalPadding: CGFloat = 14
    static let textAreaMinHeight: CGFloat = 130
    static let suggestionChipSpacing: CGFloat = 8
    static let responseAvatarSize: CGFloat = 28
    static let liveStatusDotSize: CGFloat = 8
    static let confirmIconFrame: CGFloat = 80
    static let confirmIconSize: CGFloat = 34
    static let bottomPadding: CGFloat = 32
    static let contentTopSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 8
    static let navTopPadding: CGFloat = 16
    static let navBottomPadding: CGFloat = 10
    static let stepIndicatorBottomPadding: CGFloat = 14
    static let friendRowAvatarSize: CGFloat = 40
    static let memberCountIconSize: CGFloat = 10
    static let sectionLabelSpacing: CGFloat = 12
    static let groupCardSpacing: CGFloat = 10
    static let groupCheckmarkSize: CGFloat = 16
    static let groupCardCheckOffset: CGFloat = 3
    static let rowHorizontalPadding: CGFloat = 14
    static let rowVerticalPadding: CGFloat = 10
    static let rowCornerRadius: CGFloat = 18
    static let selectionCircleSize: CGFloat = 20
    static let chipAvatarSize: CGFloat = 22
    static let chipIconSize: CGFloat = 9
    static let charCounterSpacing: CGFloat = 8
    static let responseDividerHeight: CGFloat = 40
    static let responseGroupSpacing: CGFloat = 6
    static let responseCardSpacing: CGFloat = 12
    static let pillStrokeWidth: CGFloat = 1.2
    static let actionButtonSpacing: CGFloat = 12
}

enum StartPushColor {
    static let rowFillOpacity = 0.28
    static let selectedStrokeOpacity = 0.3
    static let textEditorFill = 0.24
    static let textEditorStrokeOpacity = 0.18
    static let pillSelectedStrokeOpacity = 0.3
    static let avatarOverlayStroke: CGFloat = 1.5
}

struct StartPushStepIndicator: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: StartPushLayout.dotSpacing) {
            ForEach(1...StartPushLayout.stepCount, id: \.self) { step in
                stepDot(step: step)
            }
        }
    }

    @ViewBuilder
    private func stepDot(step: Int) -> some View {
        if step == currentStep {
            Text("\(step)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(width: StartPushLayout.dotActiveWidth, height: StartPushLayout.dotActiveHeight)
                .background(Capsule().fill(PushControlColors.activeFill))
        } else {
            Circle()
                .fill(step < currentStep
                      ? PushColorPalette.Accent.walnut.opacity(0.45)
                      : PushColorPalette.Accent.walnut.opacity(0.18))
                .frame(width: StartPushLayout.dotSize, height: StartPushLayout.dotSize)
        }
    }
}

struct StartPushHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: StartPushLayout.headerSpacing) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PushControlColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StartPushPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(isEnabled
                                 ? PushControlColors.activeForeground
                                 : PushControlColors.inactiveForeground)
                .frame(maxWidth: .infinity)
                .frame(height: StartPushLayout.primaryButtonHeight)
                .background(
                    Capsule().fill(isEnabled
                                   ? PushControlColors.activeFill
                                   : PushControlColors.activeFill.opacity(0.45))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.18), value: isEnabled)
        .accessibilityLabel(title)
    }
}

struct RecipientAvatarView: View {
    let imageAssetName: String?
    let initials: String
    let size: CGFloat

    var body: some View {
        avatarContent
            .frame(width: size, height: size)
            .clipShape(Circle())
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let image = PushImageAssets.image(named: imageAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Text(initials)
                .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(width: size, height: size)
                .background(Circle().fill(PushControlColors.activeFill))
        }
    }
}

struct StartPushSearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: StartPushLayout.searchIconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textTertiary)
            TextField(placeholder, text: $text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PushControlColors.textEspresso)
                .tint(PushControlColors.activeForeground)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: StartPushLayout.searchIconSize))
                        .foregroundStyle(PushControlColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: StartPushLayout.searchBarHeight)
        .pushGlassBackground(cornerRadius: StartPushLayout.searchBarHeight / 2)
    }
}

struct StartPushSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.bold))
            .foregroundStyle(PushControlColors.textTertiary)
            .textCase(.uppercase)
            .kerning(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
