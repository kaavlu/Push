//
//  PushPlansPlanCard.swift
//  Push
//
//  DS-024 — Plans-glass plan-card family (owner vs invited).
//

import SwiftUI

enum PushPlansPlanCardRole {
    /// Creator-owned push — Manage + optional cancel; no RSVP pill in footer.
    case owner
    /// Invited push — Manage + plan status pill + social proof separator.
    case invited
}

/// Single Plans-glass card for Pushes tab previews and owned-list rows.
struct PushPlansPlanCard: View {
    @Environment(\.pushLayout) private var layout
    let plan: PlanData
    let role: PushPlansPlanCardRole
    let onManage: () -> Void
    var onCancel: (() -> Void)? = nil

    @State private var isCancelConfirmationPresented = false

    private var groupLocationText: String {
        PushPlanCardMetadata.groupLocation(group: plan.group, locationHint: plan.locationHint)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.cardRowSpacing(layout)) {
            headerRow
            if !groupLocationText.isEmpty { groupLocationRow }
            Divider()
                .background(PlansColor.creamBase.opacity(PlansLayout.cardDividerOpacity))
            if !plan.participants.isEmpty {
                PushPlanAvatarStrip(participants: plan.participants)
            }
            footerRow
        }
        .padding(PlansLayout.cardPadding(layout))
        .pushPlansCardGlass(cornerRadius: PlansLayout.cardCornerRadius(layout))
        .contextMenu { cancelMenu }
        .confirmationDialog(
            "Cancel this push?",
            isPresented: $isCancelConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Cancel push", role: .destructive) { onCancel?() }
            Button("Keep push", role: .cancel) {}
        }
    }

    private var headerRow: some View {
        HStack(alignment: role == .owner ? .center : .top) {
            Text(plan.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: PushPlanCardMetrics.headerSpacerMinLength)
            YourPushTimeChip(timeSignal: plan.timeSignal)
        }
    }

    private var groupLocationRow: some View {
        Text(groupLocationText)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(
                role == .owner
                    ? PlansColor.metadataTertiary
                    : PlansColor.metadataSecondary
            )
            .lineLimit(1)
    }

    private var footerRow: some View {
        HStack(alignment: .center) {
            Text(plan.socialProof)
                .font(.footnote)
                .foregroundStyle(PlansColor.metadataSecondary)
                .lineLimit(2)

            if role == .invited {
                Text(PlansMetadata.separator)
                    .font(.footnote)
                    .foregroundStyle(PlansColor.metadataTertiary)
                PushPlanStatusPill(status: plan.status)
            }

            Spacer(minLength: PushPlanCardMetrics.headerSpacerMinLength)

            Button(action: onManage) {
                Text("Manage →")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PushColorPalette.Accent.walnut)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, role == .owner ? PushPlanCardMetrics.footerTopPadding : 0)
    }

    @ViewBuilder
    private var cancelMenu: some View {
        if role == .owner, onCancel != nil {
            Button("Cancel push", systemImage: "xmark.circle", role: .destructive) {
                isCancelConfirmationPresented = true
            }
            .accessibilityIdentifier("cancelPushButton")
        }
    }
}

// MARK: - Semantic wrappers

struct YourPushCard: View {
    let plan: PlanData
    let onManage: () -> Void
    var onCancel: (() -> Void)? = nil

    var body: some View {
        PushPlansPlanCard(
            plan: plan,
            role: .owner,
            onManage: onManage,
            onCancel: onCancel
        )
    }
}

struct ActivePlanCard: View {
    let plan: PlanData
    let onManage: () -> Void

    var body: some View {
        PushPlansPlanCard(
            plan: plan,
            role: .invited,
            onManage: onManage
        )
    }
}
