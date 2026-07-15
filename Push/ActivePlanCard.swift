// Push/ActivePlanCard.swift
import SwiftUI

struct ActivePlanCard: View {
    @Environment(\.pushLayout) private var layout
    let plan: PlanData
    let onManage: () -> Void

    private var groupLocationText: String {
        PlansMetadata.joined([plan.group, plan.locationHint])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.cardRowSpacing(layout)) {
            headerRow
            if !groupLocationText.isEmpty { groupRow }
            Divider()
                .background(PlansColor.creamBase.opacity(PlansLayout.cardDividerOpacity))
            if !plan.participants.isEmpty { goingSection }
            footerRow
        }
        .padding(PlansLayout.cardPadding(layout))
        .plansGlassCard(cornerRadius: PlansLayout.cardCornerRadius(layout))
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            Text(plan.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(2)
            Spacer(minLength: 8)
            YourPushTimeChip(timeSignal: plan.timeSignal)
        }
    }

    private var groupRow: some View {
        HStack(alignment: .top) {
            if !groupLocationText.isEmpty {
                Text(groupLocationText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PlansColor.metadataSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var goingSection: some View {
        YourPushAvatarRow(participants: plan.participants)
    }

    private var footerRow: some View {
        HStack(alignment: .center) {
            Text(plan.socialProof)
                .font(.footnote)
                .foregroundStyle(PlansColor.metadataSecondary)
                .lineLimit(2)
            Text(PlansMetadata.separator)
                .font(.footnote)
                .foregroundStyle(PlansColor.metadataTertiary)
            PlanStatusPill(status: plan.status)
            Spacer(minLength: YourPushCardLayout.headerSpacerMinLength)
            Button(action: onManage) {
                Text("Manage →")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PushColorPalette.Accent.walnut)
            }
            .buttonStyle(.plain)
        }
    }
}
