//
//  PushPlanCardSubcomponents.swift
//  Push
//
//  DS-024 / DS-025 — shared plan-card subcomponents (not full card chrome).
//

import SwiftUI

// MARK: - Layout

enum PushPlanCardMetrics {
    static let avatarSize: CGFloat = 28
    static let avatarSpacing: CGFloat = 6
    static let avatarStrokeWidth: CGFloat = 0.8
    static let avatarRingOpacity = 0.86
    static let maxVisibleAvatars = 4
    static let overflowFontSize: CGFloat = 11
    static let headerSpacerMinLength: CGFloat = 8
    static let footerTopPadding: CGFloat = 4
    static let statusPillHorizontalPadding: CGFloat = 10
    static let statusPillVerticalPadding: CGFloat = 5
}

// MARK: - Status pill (DS-046)

/// Plan/RSVP status capsule for Plans-glass and Review deck cards.
struct PushPlanStatusPill: View {
    let status: PlanStatus

    var body: some View {
        Text(status.pill)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, PushPlanCardMetrics.statusPillHorizontalPadding)
            .padding(.vertical, PushPlanCardMetrics.statusPillVerticalPadding)
            .background(Capsule().fill(backgroundColor))
    }

    private var foregroundColor: Color {
        switch status {
        case .pending:   return PushColorPalette.Accent.walnut
        case .joined:    return PushColorPalette.Accent.sageGreen
        case .open:      return PlansColor.maybeForeground
        case .waiting:   return PlansColor.passForeground
        case .locked:    return PushColorPalette.Accent.walnut
        case .happening: return PushColorPalette.Accent.walnut
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .pending:   return PushColorPalette.Accent.sunbeam.opacity(0.7)
        case .joined:    return PushColorPalette.Accent.mintFoam
        case .open:      return PlansColor.maybeBackground
        case .waiting:   return PlansColor.passBackground
        case .locked:    return PushColorPalette.Accent.sunbeam
        case .happening: return PushColorPalette.Accent.sunbeam
        }
    }
}

/// Migration shim — prefer `PushPlanStatusPill`.
typealias PlanStatusPill = PushPlanStatusPill

// MARK: - Avatar strip (DS-053 horizontal)

/// Horizontal participant faces + “+N” overflow for plan cards.
struct PushPlanAvatarStrip: View {
    let participants: [HangoutPerson]
    var maxVisible: Int = PushPlanCardMetrics.maxVisibleAvatars

    private var visible: [HangoutPerson] {
        Array(participants.prefix(maxVisible))
    }

    private var overflowCount: Int {
        max(0, participants.count - maxVisible)
    }

    var body: some View {
        HStack(spacing: PushPlanCardMetrics.avatarSpacing) {
            ForEach(visible) { person in
                ProfilePhotoAvatar(
                    imageAssetName: person.imageAssetName,
                    fallbackInitials: person.initials
                )
                .frame(
                    width: PushPlanCardMetrics.avatarSize,
                    height: PushPlanCardMetrics.avatarSize
                )
                .overlay {
                    Circle()
                        .stroke(
                            .white.opacity(PushPlanCardMetrics.avatarRingOpacity),
                            lineWidth: PushPlanCardMetrics.avatarStrokeWidth
                        )
                }
            }
            if overflowCount > 0 {
                PushPlanAvatarOverflowBubble(count: overflowCount)
            }
        }
    }
}

private struct PushPlanAvatarOverflowBubble: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(.system(
                size: PushPlanCardMetrics.overflowFontSize,
                weight: .semibold,
                design: .rounded
            ))
            .foregroundStyle(PushControlColors.textEspresso)
            .frame(
                width: PushPlanCardMetrics.avatarSize,
                height: PushPlanCardMetrics.avatarSize
            )
            .background(Circle().fill(PushColorPalette.Accent.sunbeam))
    }
}

/// Migration shim — prefer `PushPlanAvatarStrip`.
typealias YourPushAvatarRow = PushPlanAvatarStrip

// MARK: - Metadata

enum PushPlanCardMetadata {
    static func groupLocation(group: String, locationHint: String) -> String {
        PlansMetadata.joined([group, locationHint])
    }
}
