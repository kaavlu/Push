// Push/YourPushCard.swift
import SwiftUI

struct YourPushCard: View {
    @Environment(\.pushLayout) private var layout
    @State private var isCancelConfirmationPresented = false
    let plan: PlanData
    let onManage: () -> Void
    /// Optional so previews/tests that don't care about cancel can omit it.
    var onCancel: (() -> Void)? = nil

    private var groupLocationText: String {
        PlansMetadata.joined([plan.group, plan.locationHint])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.cardRowSpacing(layout)) {
            headerRow
            if !groupLocationText.isEmpty { groupLocationRow }
            Divider()
                .background(PlansColor.creamBase.opacity(PlansLayout.cardDividerOpacity))
            if !plan.participants.isEmpty { joinedSection }
            footerRow
        }
        .padding(PlansLayout.cardPadding(layout))
        .plansGlassCard(cornerRadius: PlansLayout.cardCornerRadius(layout))
        .contextMenu {
            if onCancel != nil {
                Button("Cancel push", systemImage: "xmark.circle", role: .destructive) {
                    isCancelConfirmationPresented = true
                }
                .accessibilityIdentifier("cancelPushButton")
            }
        }
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
        HStack(alignment: .center) {
            Text(plan.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: YourPushCardLayout.headerSpacerMinLength)
            YourPushTimeChip(timeSignal: plan.timeSignal)
        }
    }

    private var groupLocationRow: some View {
        Text(groupLocationText)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PlansColor.metadataTertiary)
            .lineLimit(1)
    }

    private var joinedSection: some View {
        YourPushAvatarRow(participants: plan.participants)
    }

    private var footerRow: some View {
        HStack(alignment: .center) {
            Text(plan.socialProof)
                .font(.footnote)
                .foregroundStyle(PlansColor.metadataSecondary)
                .lineLimit(2)
            Spacer(minLength: YourPushCardLayout.headerSpacerMinLength)
            Button(action: onManage) {
                Text("Manage →")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PushColorPalette.Accent.walnut)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, YourPushCardLayout.footerTopPadding)
    }
}

struct YourPushTimeChip: View {
    let timeSignal: String

    var body: some View {
        Text(timeSignal)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PushControlColors.textEspresso)
            .padding(.horizontal, YourPushCardLayout.timeChipHorizontalPadding)
            .padding(.vertical, YourPushCardLayout.timeChipVerticalPadding)
            .background {
                Capsule()
                    .fill(PushColorPalette.Accent.sunbeam)
            }
            .overlay {
                Capsule()
                    .stroke(
                        PlansColor.creamBase.opacity(YourPushCardLayout.timeChipStrokeOpacity),
                        lineWidth: YourPushCardLayout.timeChipStrokeWidth
                    )
            }
    }
}

struct YourPushAvatarRow: View {
    let participants: [HangoutPerson]

    private var visible: [HangoutPerson] {
        Array(participants.prefix(YourPushCardLayout.maxVisibleAvatars))
    }

    private var overflowCount: Int {
        max(0, participants.count - YourPushCardLayout.maxVisibleAvatars)
    }

    var body: some View {
        HStack(spacing: YourPushCardLayout.avatarSpacing) {
            ForEach(visible) { person in
                ProfilePhotoAvatar(
                    imageAssetName: person.imageAssetName,
                    fallbackInitials: person.initials
                )
                .frame(
                    width: YourPushCardLayout.avatarSize,
                    height: YourPushCardLayout.avatarSize
                )
                .overlay {
                    Circle()
                        .stroke(
                            .white.opacity(YourPushCardLayout.avatarRingOpacity),
                            lineWidth: YourPushCardLayout.avatarStrokeWidth
                        )
                }
            }
            if overflowCount > 0 {
                YourPushOverflowBubble(count: overflowCount)
            }
        }
    }
}

private struct YourPushOverflowBubble: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(.system(size: YourPushCardLayout.overflowFontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(PushControlColors.textEspresso)
            .frame(
                width: YourPushCardLayout.overflowAvatarSize,
                height: YourPushCardLayout.overflowAvatarSize
            )
            .background(
                Circle().fill(PushColorPalette.Accent.sunbeam)
            )
    }
}
