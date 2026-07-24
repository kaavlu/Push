//
//  CreateActionMenuView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI

struct CreateActionMenuView: View {
    @Environment(\.pushLayout) private var layout
    let action: (CreateActionMenuItem) -> Void

    var body: some View {
        VStack(spacing: CreateActionMenuLayout.rowSpacing(layout)) {
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
        .padding(CreateActionMenuLayout.cardPadding(layout))
        .frame(width: CreateActionMenuLayout.cardWidth(layout))
        .pushGlassBackground(cornerRadius: CreateActionMenuLayout.cardCornerRadius(layout))
        .shadow(
            color: PushColorPalette.Accent.walnut.opacity(CreateActionMenuColor.cardShadowOpacity),
            radius: CreateActionMenuLayout.cardShadowRadius,
            y: CreateActionMenuLayout.cardShadowYOffset
        )
    }
}

private struct CreateActionMenuRow: View {
    @Environment(\.pushLayout) private var layout
    let item: CreateActionMenuItem

    var body: some View {
        HStack(spacing: CreateActionMenuLayout.iconSpacing(layout)) {
            PushCreateMenuIconCircle(systemImageName: item.symbolName)

            VStack(alignment: .leading, spacing: CreateActionMenuLayout.textSpacing) {
                Text(item.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)

                Text(item.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PushControlColors.inactiveForeground)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(CreateActionMenuLayout.rowPadding(layout))
        .background {
            RoundedRectangle(cornerRadius: CreateActionMenuLayout.rowCornerRadius, style: .continuous)
                .fill(.white.opacity(CreateActionMenuColor.rowFillOpacity))
        }
    }
}

enum CreateActionMenuLayout {
    static let backdropOpacity = 0.12
    static func cardWidth(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 266, standard: 280, large: 292) }
    static func cardPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 8, standard: 9, large: 10) }
    static func cardCornerRadius(_ layout: PushAdaptiveLayout) -> CGFloat { layout.cardCornerRadius }
    static func cardBottomPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 88, standard: 96, large: 104) }
    static let cardShadowRadius: CGFloat = 24
    static let cardShadowYOffset: CGFloat = 12
    static func rowSpacing(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 4, standard: 5, large: 6) }
    static func rowPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 10, standard: 11, large: 12) }
    static let rowCornerRadius: CGFloat = 20
    static func iconSpacing(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 10, standard: 11, large: 12) }
    static let iconSize: CGFloat = 16
    static func iconFrame(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 34, standard: 36, large: 38) }
    static let textSpacing: CGFloat = 3
    static let animationResponse = 0.26
    static let animationDamping = 0.88
    static let transitionScale = 0.94
}

private enum CreateActionMenuColor {
    static let rowFillOpacity = 0.3
    static let cardShadowOpacity = 0.18
}
