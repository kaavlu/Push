//
//  PushContributionChip.swift
//  Push
//
//  DS-091 — compact moment-contribution capsule for chooser rows.
//  Not availability (DS-044) and not brand status pills (DS-045).
//

import SwiftUI

/// Visual kind for moment contribution labels on solid-cream chooser rows.
enum PushContributionChipKind: Equatable {
    /// Sunbeam fill — e.g. “Open for adds”.
    case openForAdds
    /// Muted walnut fill — e.g. “You contributed”.
    case youContributed
}

enum PushContributionChipMetrics {
    static let horizontalPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 3
    static let strokeWidth: CGFloat = 0.8
    static let mutedFillOpacity = 0.10
    static let openFillOpacity = 0.92
    static let openStrokeOpacity = 0.18
}

/// Compact contribution chip for moment chooser secondary lines.
struct PushContributionChip: View {
    let title: String
    let kind: PushContributionChipKind

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, PushContributionChipMetrics.horizontalPadding)
            .padding(.vertical, PushContributionChipMetrics.verticalPadding)
            .background(Capsule().fill(fill))
            .overlay {
                Capsule()
                    .stroke(stroke, lineWidth: PushContributionChipMetrics.strokeWidth)
            }
            .lineLimit(1)
    }

    private var foreground: Color {
        switch kind {
        case .openForAdds:
            return PushControlColors.activeForeground
        case .youContributed:
            return PushControlColors.textSecondary
        }
    }

    private var fill: Color {
        switch kind {
        case .openForAdds:
            return PushColorPalette.Accent.sunbeam.opacity(
                PushContributionChipMetrics.openFillOpacity
            )
        case .youContributed:
            return PushColorPalette.Accent.walnut.opacity(
                PushContributionChipMetrics.mutedFillOpacity
            )
        }
    }

    private var stroke: Color {
        switch kind {
        case .openForAdds:
            return PushColorPalette.Accent.walnut.opacity(
                PushContributionChipMetrics.openStrokeOpacity
            )
        case .youContributed:
            return Color.clear
        }
    }
}

#if DEBUG
struct PushContributionChip_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            HStack(spacing: 8) {
                PushContributionChip(title: "Open for adds", kind: .openForAdds)
                PushContributionChip(title: "You contributed", kind: .youContributed)
            }
            .padding()
            .background(PushIvoryPageBackground())
        }
    }
}
#endif
