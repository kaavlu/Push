// Push/YourPushCard.swift
import SwiftUI

struct YourPushCard: View {
    let plan: PlanData
    let onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.cardRowSpacing) {
            headerRow
            groupLocationRow
            Divider()
                .background(PushColorPalette.Accent.walnut.opacity(0.12))
            joinedSection
            footerRow
        }
        .padding(PlansLayout.cardPadding)
        .pushGlassBackground(cornerRadius: PlansLayout.cardCornerRadius)
    }

    private var headerRow: some View {
        HStack(alignment: .center) {
            Text(plan.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(1)
            Spacer(minLength: 8)
            YourPushTimeChip(timeSignal: plan.timeSignal)
        }
    }

    private var groupLocationRow: some View {
        Text("\(plan.group) · \(plan.locationHint)")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PushControlColors.textSecondary)
            .lineLimit(1)
    }

    private var joinedSection: some View {
        VStack(alignment: .leading, spacing: YourPushCardLayout.joinedLabelSpacing) {
            Text("Joined:")
                .font(.caption.weight(.medium))
                .foregroundStyle(PushControlColors.textTertiary)
            YourPushAvatarRow(participants: plan.participants)
        }
    }

    private var footerRow: some View {
        HStack {
            Text(plan.socialProof)
                .font(.footnote)
                .foregroundStyle(PushControlColors.textSecondary)
            Spacer()
            Button(action: onManage) {
                Text("Manage →")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PushControlColors.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, YourPushCardLayout.footerTopPadding)
    }
}

private struct YourPushTimeChip: View {
    let timeSignal: String

    var body: some View {
        Text(timeSignal)
            .font(.caption.weight(.semibold))
            .foregroundStyle(PushControlColors.textPrimary)
            .padding(.horizontal, YourPushCardLayout.timeChipHorizontalPadding)
            .padding(.vertical, YourPushCardLayout.timeChipVerticalPadding)
            .overlay {
                Capsule()
                    .stroke(
                        PushColorPalette.Accent.walnut.opacity(YourPushCardLayout.timeChipStrokeOpacity),
                        lineWidth: 1
                    )
            }
    }
}

private struct YourPushAvatarRow: View {
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
                            .white.opacity(0.86),
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
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(PushControlColors.textPrimary)
            .frame(
                width: YourPushCardLayout.overflowAvatarSize,
                height: YourPushCardLayout.overflowAvatarSize
            )
            .background(
                Circle().fill(PushColorPalette.Accent.sunbeam)
            )
    }
}
