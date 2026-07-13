// Push/ActivePlanCard.swift
import SwiftUI

struct ActivePlanCard: View {
    @Environment(\.pushLayout) private var layout
    let plan: PlanData

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.cardRowSpacing(layout)) {
            headerRow
            groupRow
            Divider()
                .background(PlansColor.creamBase.opacity(PlansLayout.cardDividerOpacity))
            goingSection
            socialProofRow
            locationRow
        }
        .padding(PlansLayout.cardPadding(layout))
        .frame(minHeight: PlansLayout.pushCardMinHeight(layout), alignment: .top)
        .plansGlassCard(cornerRadius: PlansLayout.cardCornerRadius(layout))
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            Text(plan.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(2)
            Spacer(minLength: 8)
            PlanStatusPill(status: plan.status)
        }
    }

    private var groupRow: some View {
        Text("\(plan.group) · \(plan.timeSignal)")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PlansColor.metadataSecondary)
            .lineLimit(1)
    }

    private var socialProofRow: some View {
        Text(plan.socialProof)
            .font(.subheadline)
            .foregroundStyle(PlansColor.metadataSecondary)
            .lineLimit(2)
    }

    private var goingSection: some View {
        VStack(alignment: .leading, spacing: YourPushCardLayout.joinedLabelSpacing) {
            Text("Going:")
                .font(.caption.weight(.medium))
                .foregroundStyle(PlansColor.metadataSecondary)
            YourPushAvatarRow(participants: plan.participants)
        }
    }

    private var locationRow: some View {
        Text(plan.locationHint)
            .font(.footnote.weight(.medium))
            .foregroundStyle(PlansColor.metadataTertiary)
            .lineLimit(1)
    }
}
