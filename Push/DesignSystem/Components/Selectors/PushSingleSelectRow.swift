//
//  PushSingleSelectRow.swift
//  Push
//
//  DS-037 — shared sunbeam-fill + checkmark single-select row primitive.
//

import SwiftUI

enum PushSingleSelectRowMetrics {
    static let iconSpacing: CGFloat = 8
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 10
    static let checkmarkSize: CGFloat = 12
}

/// Selected look: sunbeam capsule + trailing checkmark. Pair with map-glass
/// (or another approved panel surface) — this is the row primitive only.
struct PushSingleSelectRow: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: PushSingleSelectRowMetrics.iconSpacing) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(
                    isSelected
                        ? PushControlColors.activeForeground
                        : PushControlColors.inactiveForeground
                )

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: PushSingleSelectRowMetrics.checkmarkSize, weight: .bold))
                    .foregroundStyle(PushControlColors.activeForeground)
            }
        }
        .padding(.horizontal, PushSingleSelectRowMetrics.horizontalPadding)
        .padding(.vertical, PushSingleSelectRowMetrics.verticalPadding)
        .background {
            if isSelected {
                Capsule().fill(PushControlColors.activeFill)
            }
        }
    }
}
