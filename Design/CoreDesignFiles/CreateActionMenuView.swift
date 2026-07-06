//
//  CreateActionMenuView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI

struct CreateActionMenuView: View {
    let action: (CreateActionMenuItem) -> Void

    var body: some View {
        VStack(spacing: CreateActionMenuLayout.rowSpacing) {
            ForEach(CreateActionMenuItem.allCases) { item in
                Button {
                    action(item)
                } label: {
                    CreateActionMenuRow(item: item)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityHint(item.subtitle)
            }
        }
        .padding(CreateActionMenuLayout.cardPadding)
        .frame(width: CreateActionMenuLayout.cardWidth)
        .pushGlassBackground(cornerRadius: CreateActionMenuLayout.cardCornerRadius)
        .shadow(
            color: PushColorPalette.Accent.walnut.opacity(CreateActionMenuColor.cardShadowOpacity),
            radius: CreateActionMenuLayout.cardShadowRadius,
            y: CreateActionMenuLayout.cardShadowYOffset
        )
    }
}

private struct CreateActionMenuRow: View {
    let item: CreateActionMenuItem

    var body: some View {
        HStack(spacing: CreateActionMenuLayout.iconSpacing) {
            Image(systemName: item.symbolName)
                .font(.system(size: CreateActionMenuLayout.iconSize, weight: .bold))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(width: CreateActionMenuLayout.iconFrame, height: CreateActionMenuLayout.iconFrame)
                .background(Circle().fill(PushControlColors.activeFill))

            VStack(alignment: .leading, spacing: CreateActionMenuLayout.textSpacing) {
                Text(item.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)

                Text(item.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PushControlColors.inactiveForeground)
            }

            Spacer(minLength: 0)
        }
        .padding(CreateActionMenuLayout.rowPadding)
        .background {
            RoundedRectangle(cornerRadius: CreateActionMenuLayout.rowCornerRadius, style: .continuous)
                .fill(.white.opacity(CreateActionMenuColor.rowFillOpacity))
        }
    }
}

enum CreateActionMenuLayout {
    static let backdropOpacity = 0.12
    static let cardWidth: CGFloat = 292
    static let cardPadding: CGFloat = 10
    static let cardCornerRadius: CGFloat = 26
    static let cardBottomPadding: CGFloat = 104
    static let cardShadowRadius: CGFloat = 24
    static let cardShadowYOffset: CGFloat = 12
    static let rowSpacing: CGFloat = 6
    static let rowPadding: CGFloat = 12
    static let rowCornerRadius: CGFloat = 20
    static let iconSpacing: CGFloat = 12
    static let iconSize: CGFloat = 16
    static let iconFrame: CGFloat = 38
    static let textSpacing: CGFloat = 3
    static let animationResponse = 0.26
    static let animationDamping = 0.88
    static let transitionScale = 0.94
}

private enum CreateActionMenuColor {
    static let rowFillOpacity = 0.3
    static let cardShadowOpacity = 0.18
}
