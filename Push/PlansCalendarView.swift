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

private struct CalendarDayCell: View {
    let day: CalendarDayData
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if day.almostHappened {
                    Circle()
                        .stroke(
                            PushColorPalette.Accent.walnut.opacity(0.4),
                            lineWidth: PlansLayout.dotRingStrokeWidth
                        )
                        .frame(width: PlansLayout.dotMediumSize, height: PlansLayout.dotMediumSize)
                } else {
                    Circle()
                        .fill(dotColor)
                        .frame(width: dotSize, height: dotSize)
                    if day.hadPlan {
                        Circle()
                            .stroke(
                                PushColorPalette.Accent.walnut.opacity(0.6),
                                lineWidth: PlansLayout.dotRingStrokeWidth
                            )
                            .frame(
                                width: dotSize + PlansLayout.dotRingPadding,
                                height: dotSize + PlansLayout.dotRingPadding
                            )
                    }
                }
            }
            .frame(
                width: PlansLayout.calendarCellSize,
                height: PlansLayout.calendarCellSize
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var dotSize: CGFloat {
        switch day.pushCount {
        case 0:  return PlansLayout.dotEmptySize
        case 1:  return PlansLayout.dotSmallSize
        case 2:  return PlansLayout.dotMediumSize
        default: return PlansLayout.dotLargeSize
        }
    }

    private var dotColor: Color {
        switch day.pushCount {
        case 0:  return PushColorPalette.Accent.walnut.opacity(0.15)
        case 1:  return PushColorPalette.Accent.walnut.opacity(0.45)
        case 2:  return PushColorPalette.Accent.walnut.opacity(0.70)
        default: return PushColorPalette.Accent.walnut
        }
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
        VStack(alignment: .leading, spacing: 16) {
            Text(dayHeader)
                .font(.title3.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)

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

            Spacer()
        }
        .padding(24)
        .presentationDetents([.fraction(0.35)])
    }
}
