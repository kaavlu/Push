// Push/PlansCalendarView.swift
import SwiftUI

struct PlansCalendarView: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var viewModel: PlansViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            calendarHeader
                .padding(.bottom, PlansLayout.calendarHeaderSpacing)
            weekRow
            calendarFooter
                .padding(.top, PlansLayout.calendarFooterSpacing)
        }
        .padding(PlansLayout.calendarPadding(layout))
        .plansGlassCard(cornerRadius: PlansLayout.calendarCornerRadius(layout))
        .sheet(item: $viewModel.selectedDay) { day in
            DayDetailSheet(day: day)
        }
    }

    private var calendarHeader: some View {
        HStack(alignment: .center, spacing: WeeklyRecapCardLayout.headerSpacing) {
            HStack(spacing: WeeklyRecapCardLayout.weekRangeSpacing) {
                weekNavigationButton(systemName: "chevron.left") {
                    viewModel.moveWeek(by: -1)
                }

                Text(viewModel.weekLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .frame(width: WeeklyRecapCardLayout.weekLabelWidth)
                    .lineLimit(1)
                    .minimumScaleFactor(WeeklyRecapCardLayout.weekLabelMinimumScale)

                weekNavigationButton(systemName: "chevron.right") {
                    viewModel.moveWeek(by: 1)
                }
            }

            Spacer(minLength: WeeklyRecapCardLayout.headerSpacerMinLength)

            Button {
                viewModel.openHistory()
            } label: {
                Text("History ›")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushColorPalette.Accent.walnut)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open history")
        }
    }

    private func weekNavigationButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: WeeklyRecapCardLayout.chevronSize, weight: .semibold))
                .foregroundStyle(PlansColor.metadataSecondary)
                .frame(
                    width: WeeklyRecapCardLayout.chevronTapSize,
                    height: WeeklyRecapCardLayout.chevronTapSize
                )
        }
        .buttonStyle(.plain)
    }

    private var weekRow: some View {
        HStack(spacing: WeeklyRecapCardLayout.daySpacing) {
            ForEach(viewModel.weekDays) { day in
                WeeklyRecapDayTile(
                    day: day,
                    isSelected: viewModel.selectedDay?.id == day.id,
                    opensDetail: opensDetail(for: day)
                ) {
                    if opensDetail(for: day) {
                        viewModel.selectedDay = day
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func opensDetail(for day: CalendarDayData) -> Bool {
        day.pushCount > 0 || day.almostHappened
    }

    private var calendarFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(viewModel.totalPushesThisWeek) Pushes this week")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text("Most active: \(viewModel.mostActiveGroup)")
                .font(.footnote)
                .foregroundStyle(PlansColor.metadata)
            if let bestDay = viewModel.bestDayThisWeek {
                Text("Best day: \(bestDay)")
                    .font(.caption)
                    .foregroundStyle(PlansColor.metadataSecondary)
            }
        }
    }
}

private enum WeeklyRecapCardLayout {
    static let chevronSize: CGFloat = 12
    static let chevronTapSize: CGFloat = 26
    static let daySpacing: CGFloat = 6
    static let headerSpacing: CGFloat = 8
    static let headerSpacerMinLength: CGFloat = 8
    static let weekRangeSpacing: CGFloat = 6
    static let weekLabelWidth: CGFloat = 116
    static let weekLabelMinimumScale: CGFloat = 0.86
}

private struct DayDetailSheet: View {
    let day: CalendarDayData

    private var dayHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: day.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayHeader)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PushControlColors.textEspresso)

                pushCountLine
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            if !day.hangouts.isEmpty {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(day.hangouts) { hangout in
                            HangoutRow(hangout: hangout)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            } else {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Same cream glass treatment as map `FriendDetailBottomSheet` chrome.
        .presentationBackground {
            MapPopupSheetBackground()
        }
        .presentationCornerRadius(FriendDetailSheetLayout.sheetCornerRadius)
        .presentationDetents([.fraction(0.35)])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var pushCountLine: some View {
        if day.almostHappened {
            Text("Almost happened")
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textTertiary)
        } else if day.pushCount == 0 {
            Text("Nothing happened")
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textTertiary)
        } else {
            Text("\(day.pushCount) \(day.pushCount == 1 ? "Push" : "Pushes")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
        }
    }
}

private struct HangoutRow: View {
    let hangout: DayHangoutEntry

    private var namesText: String {
        let names = hangout.people.map(\.name)
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        case 3: return "\(names[0]), \(names[1]), and \(names[2])"
        default: return "\(names[0]), \(names[1]), and \(names.count - 2) others"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            HistoryPuck(people: hangout.people)
            VStack(alignment: .leading, spacing: 2) {
                Text(namesText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                Text(hangout.activityNote)
                    .font(.caption)
                    .foregroundStyle(PushControlColors.textSecondary)
                Text(hangout.duration)
                    .font(.caption2)
                    .foregroundStyle(PushControlColors.textTertiary)
            }
            Spacer()
        }
    }
}

// MARK: - History Pucks
// Mirror the geometry of FriendPuck / PairHangoutPuck / SmallGroupPuck
// but drop all live state (no availability pulse, no activity badge, no count badge).

private enum HistoryPuckLayout {
    static let size: CGFloat = 52
    // mirrors PairHangoutLayout
    static let pairAvatarScale: CGFloat = 0.60
    static let pairCenterOffsetScale: CGFloat = 0.28
    static let pairRingWidth: CGFloat = 3
    // mirrors SmallGroupLayout
    static let groupAvatarScale: CGFloat = 0.50
    static let groupRingWidth: CGFloat = 2.6
    static let groupAvatarOffsets: [CGSize] = [
        CGSize(width: -0.28, height: -0.20),
        CGSize(width:  0.28, height: -0.20),
        CGSize(width:  0.00, height:  0.28)
    ]
    static let ringStrokeOpacity: CGFloat = 0.72
}

private struct HistoryPuck: View {
    let people: [HangoutPerson]

    var body: some View {
        switch people.count {
        case 0:
            Color.clear
                .frame(width: HistoryPuckLayout.size, height: HistoryPuckLayout.size)
        case 1:
            SoloHistoryPuck(person: people[0])
        case 2:
            PairHistoryPuck(people: Array(people.prefix(2)))
        default:
            GroupHistoryPuck(people: Array(people.prefix(3)))
        }
    }
}

// Mirrors FriendPuck: glass background + circular photo, no pulse/badge.
private struct SoloHistoryPuck: View {
    let person: HangoutPerson
    private let size = HistoryPuckLayout.size

    var body: some View {
        ProfilePhotoAvatar(
            imageAssetName: person.imageAssetName,
            fallbackInitials: person.initials
        )
        .frame(width: size, height: size)
        .puckGlassBackground(cornerRadius: size / FriendPuckLayout.cornerDivisor)
    }
}

// Mirrors PairHangoutPuck geometry: two avatars offset on opposite sides.
private struct PairHistoryPuck: View {
    let people: [HangoutPerson]
    private let size = HistoryPuckLayout.size
    private var avatarSize: CGFloat { size * HistoryPuckLayout.pairAvatarScale }
    private var centerOffset: CGFloat { avatarSize * HistoryPuckLayout.pairCenterOffsetScale }

    var body: some View {
        ZStack {
            ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                ProfilePhotoAvatar(
                    imageAssetName: person.imageAssetName,
                    fallbackInitials: person.initials
                )
                .frame(width: avatarSize, height: avatarSize)
                .overlay {
                    Circle()
                        .stroke(
                            .white.opacity(HistoryPuckLayout.ringStrokeOpacity),
                            lineWidth: HistoryPuckLayout.pairRingWidth
                        )
                }
                .offset(x: index == 0 ? -centerOffset : centerOffset)
            }
        }
        .frame(width: size, height: size)
    }
}

// Mirrors SmallGroupPuck geometry: three avatars in a triangular arrangement.
private struct GroupHistoryPuck: View {
    let people: [HangoutPerson]
    private let size = HistoryPuckLayout.size
    private var avatarSize: CGFloat { size * HistoryPuckLayout.groupAvatarScale }

    private func offset(for index: Int) -> CGSize {
        let base = HistoryPuckLayout.groupAvatarOffsets
        guard base.indices.contains(index) else { return .zero }
        return CGSize(
            width: base[index].width * avatarSize,
            height: base[index].height * avatarSize
        )
    }

    var body: some View {
        ZStack {
            ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                ProfilePhotoAvatar(
                    imageAssetName: person.imageAssetName,
                    fallbackInitials: person.initials
                )
                .frame(width: avatarSize, height: avatarSize)
                .overlay {
                    Circle()
                        .stroke(
                            .white.opacity(HistoryPuckLayout.ringStrokeOpacity),
                            lineWidth: HistoryPuckLayout.groupRingWidth
                        )
                }
                .offset(offset(for: index))
            }
        }
        .frame(width: size, height: size)
    }
}
