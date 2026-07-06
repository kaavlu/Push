// Push/ActivePlanCard.swift
import SwiftUI

struct ActivePlanCard: View {
    let plan: PlanData

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.cardRowSpacing) {
            headerRow
            groupRow
            Divider()
                .background(PlansColor.creamBase.opacity(PlansLayout.cardDividerOpacity))
            goingSection
            socialProofRow
            locationRow
        }
        .padding(PlansLayout.cardPadding)
        .frame(height: PlansLayout.pushCardHeight, alignment: .top)
        .plansGlassCard(cornerRadius: PlansLayout.cardCornerRadius)
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            Text(plan.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(1)
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
            .lineLimit(1)
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
