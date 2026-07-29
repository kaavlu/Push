//
//  FeedMediaCardContentSection.swift
//  Push
//
//  Cream content band under Feed media: title, location · date/time, and
//  trailing same-size Add yours (+) / overflow controls. Continues the media card.
//

import SwiftUI

/// Compact padded content attached under the media frame of a feed card.
struct FeedMediaCardContentSection: View {
    let title: String
    let metaLine: String
    let canAddYours: Bool
    var onOverflowMenu: () -> Void = {}
    var onAddYours: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: FeedMediaContentSectionStyle.titleToOverflowSpacing) {
            titleMetaColumn
            // + and … only when the viewer is part of the moment.
            if canAddYours {
                trailingActions
            }
        }
        .padding(.horizontal, FeedMediaContentSectionStyle.horizontalPadding)
        .padding(.top, FeedMediaContentSectionStyle.topPadding)
        .padding(.bottom, FeedMediaContentSectionStyle.bottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PushCreamTokens.solidCard)
        .accessibilityElement(children: .contain)
    }

    private var titleMetaColumn: some View {
        VStack(alignment: .leading, spacing: FeedMediaContentSectionStyle.titleToMetaSpacing) {
            Text(title)
                .font(FeedMediaContentSectionStyle.titleFont)
                .foregroundStyle(FeedMediaContentSectionStyle.titleColor)
                .lineLimit(FeedMediaContentSectionStyle.titleLineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !metaLine.isEmpty {
                Text(metaLine)
                    .font(FeedMediaContentSectionStyle.metaFont)
                    .foregroundStyle(FeedMediaContentSectionStyle.metaColor)
                    .lineLimit(FeedMediaContentSectionStyle.metaLineLimit)
                    .minimumScaleFactor(PushOpacityTokens.minimumTextScale)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Sunbeam + and glass … — identical diameter (`PushCircleIconButtonMetrics.size`).
    private var trailingActions: some View {
        HStack(spacing: FeedMediaContentSectionStyle.actionSpacing) {
            FeedMediaAddYoursCircleButton(action: onAddYours)
            PushCircleIconButton(
                systemImageName: "ellipsis",
                accessibilityLabel: FeedMediaCardContentCopy.overflowAccessibility,
                action: onOverflowMenu
            )
        }
    }
}

/// Solid sunbeam circular + — matches `PushCircleIconButton` size for inline pairing.
private struct FeedMediaAddYoursCircleButton: View {
    let action: () -> Void

    private var size: CGFloat { PushCircleIconButtonMetrics.size }
    private var iconSize: CGFloat { PushCircleIconButtonMetrics.iconSize }

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: iconSize, weight: PushCircleIconButtonMetrics.iconWeight))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(width: size, height: size)
                .background(Circle().fill(PushControlColors.activeFill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(FeedMediaCardContentCopy.addYoursAccessibility)
    }
}

enum FeedMediaCardContentCopy {
    static let addYoursAccessibility = "Add yours"
    static let overflowAccessibility = "Edit moment"
}

#if DEBUG
struct FeedMediaCardContentSection_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            VStack(spacing: 16) {
                FeedMediaCardContentSection(
                    title: "Friday night out",
                    metaLine: "The Beehive · Fri · 9:15 PM",
                    canAddYours: true
                )
                FeedMediaCardContentSection(
                    title: "Beach morning",
                    metaLine: "Ocean Beach · Sun · 11:00 AM",
                    canAddYours: false
                )
            }
            .padding()
            .background(PushIvoryPageBackground())
        }
    }
}
#endif
