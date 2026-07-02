// Push/PlansCalendarView.swift
import SwiftUI

struct PlansCalendarView: View {
    @ObservedObject var viewModel: PlansViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            calendarHeader
                .padding(.bottom, PlansLayout.calendarHeaderSpacing)
            weekdayRow
                .padding(.bottom, 8)
            calendarGrid
            calendarFooter
                .padding(.top, PlansLayout.calendarFooterSpacing)
        }
        .padding(PlansLayout.calendarPadding)
        .pushGlassBackground(cornerRadius: PlansLayout.calendarCornerRadius)
        .sheet(item: $viewModel.selectedDay) { day in
            DayDetailSheet(day: day)
        }
    }

    private var calendarHeader: some View {
        HStack {
            Text(viewModel.monthLabel)
                .font(.headline.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            Spacer()
            Button {
                // history stub — future issue
            } label: {
                Text("History ›")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PushControlColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: PlansLayout.calendarCellSpacing) {
            ForEach(CalendarConstants.weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PushControlColors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let weeks = groupedIntoWeeks(viewModel.calendarDays)
        return VStack(spacing: PlansLayout.calendarCellSpacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: PlansLayout.calendarCellSpacing) {
                    ForEach(0..<7, id: \.self) { col in
                        if let day = week[col] {
                            CalendarDayCell(day: day) {
                                viewModel.selectedDay = day
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Color.clear
                                .frame(
                                    width: PlansLayout.calendarCellSize,
                                    height: PlansLayout.calendarCellSize
                                )
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var calendarFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(viewModel.totalPushesThisMonth) Pushes this month")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)
            Text("Most active: \(viewModel.mostActiveGroup)")
                .font(.footnote)
                .foregroundStyle(PushControlColors.textSecondary)
        }
    }

    private func groupedIntoWeeks(_ days: [CalendarDayData]) -> [[CalendarDayData?]] {
        guard let firstDate = days.first?.date else { return [] }
        let calendar = Calendar.current
        let weekdayOfFirst = calendar.component(.weekday, from: firstDate)
        // Monday-first: Mon=2→0, Tue=3→1, ... Sun=1→6
        let mondayOffset = (weekdayOfFirst + 5) % 7
        var slots: [CalendarDayData?] = Array(repeating: nil, count: mondayOffset)
        slots.append(contentsOf: days.map { Optional($0) })
        let remainder = slots.count % 7
        if remainder != 0 {
            slots.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }
        return stride(from: 0, to: slots.count, by: 7).map {
            Array(slots[$0..<$0 + 7])
        }
    }
}

private enum CalendarConstants {
    static let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]
}

private enum CalendarCellLayout {
    static let highlightSize: CGFloat = 24
    static let activityDotSize: CGFloat = 3
    static let dotSpacing: CGFloat = 2
}

private struct CalendarDayCell: View {
    let day: CalendarDayData
    let onTap: () -> Void

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    private var dayNumber: Int {
        Calendar.current.component(.day, from: day.date)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(PushColorPalette.Accent.sunbeam)
                        .frame(
                            width: CalendarCellLayout.highlightSize,
                            height: CalendarCellLayout.highlightSize
                        )
                } else if day.almostHappened {
                    Circle()
                        .stroke(
                            PushColorPalette.Accent.walnut.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1.0, dash: [2, 2])
                        )
                        .frame(
                            width: CalendarCellLayout.highlightSize,
                            height: CalendarCellLayout.highlightSize
                        )
                }

                VStack(spacing: CalendarCellLayout.dotSpacing) {
                    Text("\(dayNumber)")
                        .font(.caption.weight(fontWeight))
                        .foregroundStyle(textColor)

                    Circle()
                        .fill(PushColorPalette.Accent.walnut.opacity(0.6))
                        .frame(
                            width: CalendarCellLayout.activityDotSize,
                            height: CalendarCellLayout.activityDotSize
                        )
                        .opacity(day.pushCount > 0 && !isToday ? 1 : 0)
                }
            }
            .frame(width: PlansLayout.calendarCellSize, height: PlansLayout.calendarCellSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var fontWeight: Font.Weight {
        if isToday { return .bold }
        if day.pushCount > 0 { return .semibold }
        return .regular
    }

    private var textColor: Color {
        if isToday { return PushControlColors.textEspresso }
        if day.pushCount > 0 { return PushControlColors.textPrimary }
        return PushControlColors.textTertiary
    }

    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: day.date)), \(day.pushCount) pushes"
    }
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
