// Push/ReviewPushCard.swift
//
// The compact liquid-glass push card shown in the Review Pushes deck. Unlike
// the small ActivePlanCard preview on the Pushes tab, this surfaces the full
// detail a friend needs to decide — everyone coming, the creator's notes, the
// address, and how far away it is — while staying content-sized and swipeable.

import SwiftUI

struct ReviewPushCard: View {
    let plan: PlanData

    var body: some View {
        VStack(alignment: .leading, spacing: ReviewPushCardLayout.sectionSpacing) {
            header
            Divider().background(dividerTint)
            attendees
            if let note = plan.note, !note.isEmpty {
                notesSection(note)
            }
            Divider().background(dividerTint)
            locationFooter
        }
        .padding(ReviewPushCardLayout.cardPadding)
        .reviewGlassCard(cornerRadius: ReviewPushCardLayout.cardCornerRadius)
    }

    private var dividerTint: Color {
        PlansColor.creamBase.opacity(ReviewPushCardLayout.dividerOpacity)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ReviewPushCardLayout.headerSpacing) {
            HStack(alignment: .top) {
                Text(plan.title)
                    .font(.system(size: ReviewPushCardLayout.titleSize, weight: .bold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .lineLimit(2)
                Spacer(minLength: ReviewPushCardLayout.rowSpacing)
                PlanStatusPill(status: plan.status)
            }
            Label("\(plan.group) · \(plan.timeSignal)", systemImage: "clock")
                .font(.system(size: ReviewPushCardLayout.metadataSize, weight: .medium))
                .foregroundStyle(PlansColor.metadataSecondary)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
        }
    }

    // MARK: - Attendees

    private var attendees: some View {
        VStack(alignment: .leading, spacing: ReviewPushCardLayout.labelSpacing) {
            ReviewSectionLabel(title: "Who's coming", trailing: plan.socialProof)
            if plan.participants.isEmpty {
                Text("No one's committed yet — be the first.")
                    .font(.system(size: ReviewPushCardLayout.bodySize))
                    .foregroundStyle(PlansColor.metadataTertiary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(namedParticipants) { person in
                        ReviewParticipantRow(person: person)
                    }
                    if overflowCount > 0 {
                        Text("+\(overflowCount) more going")
                            .font(.system(size: ReviewPushCardLayout.detailSize, weight: .semibold))
                            .foregroundStyle(PlansColor.metadataSecondary)
                            .padding(.top, ReviewPushCardLayout.rowSpacing)
                    }
                }
            }
            if !plan.maybeParticipants.isEmpty {
                ReviewMaybeRow(people: plan.maybeParticipants)
            }
        }
    }

    private var namedParticipants: [HangoutPerson] {
        Array(plan.participants.prefix(ReviewPushCardLayout.maxNamedParticipants))
    }

    private var overflowCount: Int {
        max(0, plan.participants.count - ReviewPushCardLayout.maxNamedParticipants)
    }

    // MARK: - Notes

    private func notesSection(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: ReviewPushCardLayout.labelSpacing) {
            ReviewSectionLabel(title: "Notes", trailing: nil)
            Text(note)
                .font(.system(size: ReviewPushCardLayout.bodySize))
                .foregroundStyle(PushControlColors.textEspresso.opacity(ReviewPushCardLayout.noteOpacity))
                .lineLimit(ReviewPushCardLayout.noteLineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Location footer

    private var locationFooter: some View {
        HStack(alignment: .center, spacing: ReviewPushCardLayout.locationSpacing) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: ReviewPushCardLayout.locationIconSize, weight: .semibold))
                .foregroundStyle(PushColorPalette.Accent.walnut)
            VStack(alignment: .leading, spacing: ReviewPushCardLayout.locationLineSpacing) {
                Text(plan.locationHint.isEmpty ? "Location TBD" : plan.locationHint)
                    .font(.system(size: ReviewPushCardLayout.locationTitleSize, weight: .semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .lineLimit(1)
                if !locationDetail.isEmpty {
                    Text(locationDetail)
                        .font(.system(size: ReviewPushCardLayout.detailSize, weight: .medium))
                        .foregroundStyle(PlansColor.metadataTertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// "315 Linden St · 4.3 mi away", skipping either half when unknown.
    private var locationDetail: String {
        [plan.address, plan.distanceLabel]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " · ")
    }
}

private struct ReviewSectionLabel: View {
    let title: String
    let trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: ReviewPushCardLayout.sectionLabelSize, weight: .semibold))
                .kerning(ReviewPushCardLayout.sectionLabelKerning)
                .foregroundStyle(PlansColor.metadataSecondary)
            Spacer(minLength: ReviewPushCardLayout.rowSpacing)
            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: ReviewPushCardLayout.detailSize, weight: .semibold))
                    .foregroundStyle(PushColorPalette.Accent.walnut)
            }
        }
    }
}

private struct ReviewParticipantRow: View {
    let person: HangoutPerson

    var body: some View {
        HStack(spacing: ReviewPushCardLayout.participantSpacing) {
            ProfilePhotoAvatar(
                imageAssetName: person.imageAssetName,
                fallbackInitials: person.initials
            )
            .frame(width: ReviewPushCardLayout.avatarSize, height: ReviewPushCardLayout.avatarSize)
            .overlay {
                Circle().stroke(
                    .white.opacity(ReviewPushCardLayout.avatarRingOpacity),
                    lineWidth: ReviewPushCardLayout.avatarStrokeWidth
                )
            }
            Text(person.name)
                .font(.system(size: ReviewPushCardLayout.nameSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textEspresso)
            Spacer(minLength: 0)
        }
        .frame(height: ReviewPushCardLayout.participantRowHeight)
    }
}

private struct ReviewMaybeRow: View {
    let people: [HangoutPerson]

    var body: some View {
        HStack(spacing: ReviewPushCardLayout.maybeAvatarSpacing) {
            ForEach(people.prefix(ReviewPushCardLayout.maxMaybeAvatars)) { person in
                ProfilePhotoAvatar(
                    imageAssetName: person.imageAssetName,
                    fallbackInitials: person.initials
                )
                .frame(
                    width: ReviewPushCardLayout.maybeAvatarSize,
                    height: ReviewPushCardLayout.maybeAvatarSize
                )
                .overlay {
                    Circle().stroke(
                        .white.opacity(ReviewPushCardLayout.avatarRingOpacity),
                        lineWidth: ReviewPushCardLayout.avatarStrokeWidth
                    )
                }
            }
            Text(maybeLabel)
                .font(.system(size: ReviewPushCardLayout.detailSize, weight: .medium))
                .foregroundStyle(PlansColor.metadataTertiary)
                .padding(.leading, ReviewPushCardLayout.maybeLabelLeading)
            Spacer(minLength: 0)
        }
        .padding(.top, ReviewPushCardLayout.rowSpacing)
    }

    private var maybeLabel: String {
        let names = people.prefix(ReviewPushCardLayout.maxMaybeNames)
            .map(\.name)
            .joined(separator: ", ")
        let extra = people.count - min(people.count, ReviewPushCardLayout.maxMaybeNames)
        return extra > 0 ? "\(names) +\(extra) maybe" : "\(names) maybe"
    }
}

enum ReviewPushCardLayout {
    // Layout
    static let cardCornerRadius: CGFloat = 30
    static let cardPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 16
    static let headerSpacing: CGFloat = 7
    static let rowSpacing: CGFloat = 8
    static let labelSpacing: CGFloat = 11
    static let participantSpacing: CGFloat = 12
    static let participantRowHeight: CGFloat = 44
    static let avatarSize: CGFloat = 36
    static let avatarStrokeWidth: CGFloat = 1.0
    static let avatarRingOpacity: Double = 0.86
    static let maybeAvatarSize: CGFloat = 27
    static let maybeAvatarSpacing: CGFloat = -7
    static let maybeLabelLeading: CGFloat = 10
    static let maxMaybeAvatars: Int = 3
    static let maxMaybeNames: Int = 2
    static let dividerOpacity: Double = 0.28
    static let noteLineLimit: Int = 3
    static let noteOpacity: Double = 0.82
    static let maxNamedParticipants: Int = 5
    static let locationSpacing: CGFloat = 10
    static let locationLineSpacing: CGFloat = 3
    static let locationIconSize: CGFloat = 22
    static let sectionLabelKerning: CGFloat = 0.8

    // Typography (points)
    static let titleSize: CGFloat = 25
    static let metadataSize: CGFloat = 16
    static let sectionLabelSize: CGFloat = 13
    static let nameSize: CGFloat = 17
    static let bodySize: CGFloat = 17
    static let locationTitleSize: CGFloat = 17
    static let detailSize: CGFloat = 14
}
