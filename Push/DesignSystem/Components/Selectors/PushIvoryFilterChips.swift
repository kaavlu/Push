//
//  PushIvoryFilterChips.swift
//  Push
//
//  DS-036 — walnut-selected filter chips for ivory pages (not sunbeam).
//

import SwiftUI

struct PushIvoryFilterItem: Identifiable, Equatable {
    let id: String
    let title: String
    /// When nil, the chip shows title only (Feed shell fixtures have no counts yet).
    var count: Int? = nil
}

enum PushIvoryFilterChipMetrics {
    static let rowSpacing: CGFloat = 8
    static let horizontalPadding: CGFloat = 13
    static let verticalPadding: CGFloat = 8
    static let countSpacing: CGFloat = 6
    static let countHorizontalPadding: CGFloat = 6
    static let countVerticalPadding: CGFloat = 1
    static let strokeWidth: CGFloat = 0.9
}

/// Horizontal filter chip row — walnut selected, cream unselected.
struct PushIvoryFilterChipRow: View {
    let items: [PushIvoryFilterItem]
    @Binding var selectedID: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PushIvoryFilterChipMetrics.rowSpacing) {
                ForEach(items) { item in
                    chip(item)
                }
            }
        }
    }

    private func chip(_ item: PushIvoryFilterItem) -> some View {
        let isSelected = selectedID == item.id
        return Button {
            withAnimation(PushMotion.selection) {
                selectedID = item.id
            }
        } label: {
            HStack(spacing: PushIvoryFilterChipMetrics.countSpacing) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                if let count = item.count {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, PushIvoryFilterChipMetrics.countHorizontalPadding)
                        .padding(.vertical, PushIvoryFilterChipMetrics.countVerticalPadding)
                        .background(
                            Capsule().fill(
                                .white.opacity(isSelected ? FriendsColor.chipCountSelectedOpacity : 0)
                            )
                        )
                        .background(
                            Capsule().fill(
                                PushColorPalette.Accent.walnut.opacity(
                                    isSelected ? 0 : FriendsColor.chipCountInactiveOpacity
                                )
                            )
                        )
                }
            }
            .foregroundStyle(isSelected ? FriendsColor.chipSelectedText : PushControlColors.textPrimary)
            .padding(.horizontal, PushIvoryFilterChipMetrics.horizontalPadding)
            .padding(.vertical, PushIvoryFilterChipMetrics.verticalPadding)
            .background(chipBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.count.map(String.init) ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func chipBackground(isSelected: Bool) -> some View {
        if isSelected {
            Capsule().fill(FriendsColor.chipSelectedFill)
        } else {
            Capsule()
                .fill(FriendsColor.cardCream.opacity(FriendsColor.cardCreamOpacity))
                .overlay {
                    Capsule().stroke(
                        PushColorPalette.Accent.walnut.opacity(FriendsColor.chipStrokeWalnutOpacity),
                        lineWidth: PushIvoryFilterChipMetrics.strokeWidth
                    )
                }
        }
    }
}
