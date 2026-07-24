//
//  PushModalChoicePill.swift
//  Push
//
//  DS-039 — sunbeam-selected / translucent-unselected compact choices in modal flows.
//

import SwiftUI

enum PushModalChoicePillMetrics {
    static let verticalPadding: CGFloat = 8
    static let selectedStrokeOpacity = 0.28
    static let strokeWidth: CGFloat = 1.5
    static let unselectedFillOpacity = 0.55
}

/// Compact choice pill for modal multi-step flows (AM/PM, similar option pills).
struct PushModalChoicePill: View {
    let title: String
    let isSelected: Bool
    var expandsHorizontally: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    isSelected
                        ? PushControlColors.activeForeground
                        : PushControlColors.textSecondary
                )
                .frame(maxWidth: expandsHorizontally ? .infinity : nil)
                .padding(.vertical, PushModalChoicePillMetrics.verticalPadding)
                .padding(.horizontal, expandsHorizontally ? 0 : 16)
                .background(
                    Capsule().fill(
                        isSelected
                            ? PushControlColors.activeFill
                            : .white.opacity(PushModalChoicePillMetrics.unselectedFillOpacity)
                    )
                )
                .overlay(
                    Capsule().stroke(
                        isSelected
                            ? PushColorPalette.Accent.walnut.opacity(
                                PushModalChoicePillMetrics.selectedStrokeOpacity
                            )
                            : .clear,
                        lineWidth: PushModalChoicePillMetrics.strokeWidth
                    )
                )
        }
        .buttonStyle(.plain)
        .animation(PushMotion.selectionSnappy, value: isSelected)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
