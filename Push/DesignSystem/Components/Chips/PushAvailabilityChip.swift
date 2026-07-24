//
//  PushAvailabilityChip.swift
//  Push
//
//  DS-044 — compact availability chip for cream lists and sheet headers.
//

import SwiftUI

enum PushAvailabilityChipDensity {
    /// Friends list trailing chip.
    case compact
    /// Friend detail sheet header (slightly taller type, tighter vertical pad).
    case sheet
}

enum PushAvailabilityChipMetrics {
    static let compactHorizontalPadding: CGFloat = 10
    static let compactVerticalPadding: CGFloat = 5
    static let sheetHorizontalPadding: CGFloat = 10
    static let sheetVerticalPadding: CGFloat = 3
    static let strokeOpacity = 0.30
    static let strokeWidth: CGFloat = 0.5
    static let minimumTextScale = 0.82
}

/// Canonical multi-color availability capsule. Map annotations use `ActivityBadge`.
struct PushAvailabilityChip: View {
    let availability: FriendAvailabilityState
    var density: PushAvailabilityChipDensity = .compact

    var body: some View {
        Text(availability.title)
            .font(titleFont)
            .foregroundStyle(availability.chipTextColor)
            .lineLimit(1)
            .minimumScaleFactor(PushAvailabilityChipMetrics.minimumTextScale)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(availability.chipFillColor, in: Capsule())
            .overlay(
                Capsule().stroke(
                    .white.opacity(PushAvailabilityChipMetrics.strokeOpacity),
                    lineWidth: PushAvailabilityChipMetrics.strokeWidth
                )
            )
    }

    private var titleFont: Font {
        switch density {
        case .compact: return .caption2.weight(.bold)
        case .sheet: return .footnote.weight(.semibold)
        }
    }

    private var horizontalPadding: CGFloat {
        switch density {
        case .compact: return PushAvailabilityChipMetrics.compactHorizontalPadding
        case .sheet: return PushAvailabilityChipMetrics.sheetHorizontalPadding
        }
    }

    private var verticalPadding: CGFloat {
        switch density {
        case .compact: return PushAvailabilityChipMetrics.compactVerticalPadding
        case .sheet: return PushAvailabilityChipMetrics.sheetVerticalPadding
        }
    }
}

/// Migration shim — prefer `PushAvailabilityChip`.
typealias FriendsAvailabilityChip = PushAvailabilityChip

#if DEBUG
struct PushAvailabilityChip_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            VStack(spacing: 12) {
                ForEach(
                    [FriendAvailabilityState.freeNow, .freeSoon, .maybeDown, .busy, .joinable, .driving],
                    id: \.self
                ) { state in
                    HStack {
                        PushAvailabilityChip(availability: state, density: .compact)
                        PushAvailabilityChip(availability: state, density: .sheet)
                    }
                }
            }
            .padding()
            .background(PushIvoryPageBackground())
        }
    }
}
#endif
