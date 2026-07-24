//
//  PushBrandSunbeamPill.swift
//  Push
//
//  DS-045 — brand sunbeam capsule for non-availability labels.
//

import SwiftUI

enum PushBrandSunbeamPillStyle {
    /// Profile identity status — symbol + title, solid sunbeam.
    case profileStatus
    /// Plan time signal — text with cream stroke.
    case planTime
    /// Group status label — sunbeam at reduced opacity fill.
    case groupStatus
}

enum PushBrandSunbeamPillMetrics {
    static let profileIconSize: CGFloat = 13
    static let profileIconSpacing: CGFloat = 7
    static let profileHorizontalPadding: CGFloat = 14
    static let profileVerticalPadding: CGFloat = 8

    static let planTimeHorizontalPadding: CGFloat = 10
    static let planTimeVerticalPadding: CGFloat = 5
    static let planTimeStrokeOpacity = 0.74
    static let planTimeStrokeWidth: CGFloat = 0.8

    static let groupHorizontalPadding: CGFloat = 10
    static let groupVerticalPadding: CGFloat = 5
    static let groupFillOpacity = 0.92
    static let groupMinimumTextScale = 0.82
}

/// Shared sunbeam-fill capsule chrome (not multi-color availability, not plan RSVP).
struct PushBrandSunbeamPill: View {
    let title: String
    var symbolName: String? = nil
    var style: PushBrandSunbeamPillStyle = .profileStatus

    var body: some View {
        content
            .foregroundStyle(foreground)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Capsule().fill(fill))
            .overlay { strokeOverlay }
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .profileStatus:
            HStack(spacing: PushBrandSunbeamPillMetrics.profileIconSpacing) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.system(size: PushBrandSunbeamPillMetrics.profileIconSize, weight: .bold))
                }
                Text(title)
                    .font(.subheadline.weight(.bold))
            }
        case .planTime:
            Text(title)
                .font(.caption.weight(.semibold))
        case .groupStatus:
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(PushBrandSunbeamPillMetrics.groupMinimumTextScale)
        }
    }

    private var foreground: Color {
        switch style {
        case .profileStatus, .groupStatus:
            return PushControlColors.activeForeground
        case .planTime:
            return PushControlColors.textEspresso
        }
    }

    private var fill: Color {
        switch style {
        case .profileStatus, .planTime:
            return PushControlColors.activeFill
        case .groupStatus:
            return PushControlColors.activeFill.opacity(PushBrandSunbeamPillMetrics.groupFillOpacity)
        }
    }

    private var horizontalPadding: CGFloat {
        switch style {
        case .profileStatus: return PushBrandSunbeamPillMetrics.profileHorizontalPadding
        case .planTime: return PushBrandSunbeamPillMetrics.planTimeHorizontalPadding
        case .groupStatus: return PushBrandSunbeamPillMetrics.groupHorizontalPadding
        }
    }

    private var verticalPadding: CGFloat {
        switch style {
        case .profileStatus: return PushBrandSunbeamPillMetrics.profileVerticalPadding
        case .planTime: return PushBrandSunbeamPillMetrics.planTimeVerticalPadding
        case .groupStatus: return PushBrandSunbeamPillMetrics.groupVerticalPadding
        }
    }

    @ViewBuilder
    private var strokeOverlay: some View {
        if style == .planTime {
            Capsule().stroke(
                PushGlassCreamTokens.creamBase.opacity(PushBrandSunbeamPillMetrics.planTimeStrokeOpacity),
                lineWidth: PushBrandSunbeamPillMetrics.planTimeStrokeWidth
            )
        }
    }
}

// MARK: - Semantic wrappers

struct StatusPill: View {
    let title: String
    let symbolName: String

    var body: some View {
        PushBrandSunbeamPill(title: title, symbolName: symbolName, style: .profileStatus)
    }
}

struct YourPushTimeChip: View {
    let timeSignal: String

    var body: some View {
        PushBrandSunbeamPill(title: timeSignal, style: .planTime)
    }
}

struct PushGroupStatusPill: View {
    let title: String

    var body: some View {
        PushBrandSunbeamPill(title: title, style: .groupStatus)
    }
}

#if DEBUG
struct PushBrandSunbeamPill_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            VStack(spacing: 12) {
                StatusPill(title: "Free now", symbolName: "sparkles")
                YourPushTimeChip(timeSignal: "Tonight · 8pm")
                PushGroupStatusPill(title: "Active")
            }
            .padding()
            .background(PushIvoryPageBackground())
        }
    }
}
#endif
