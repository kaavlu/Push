//
//  StartPushTimingPickers.swift
//  Push
//
//  Created by Manav Khanvilkar on 7/1/26.
//

import SwiftUI

// MARK: - Date Picker

struct PushDatePicker: View {
    @Environment(\.pushLayout) private var layout
    @Binding var selectedDate: Date
    @State private var displayedMonth: Date

    private let calendar = Calendar.current

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._displayedMonth = State(initialValue: selectedDate.wrappedValue)
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var canGoBack: Bool {
        let now = calendar.dateComponents([.year, .month], from: Date())
        let shown = calendar.dateComponents([.year, .month], from: displayedMonth)
        return now.year != shown.year || now.month != shown.month
    }

    private let weekdayHeaders = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    private var daysInGrid: [Date?] {
        var comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstDay = calendar.date(from: comps) else { return [] }

        let leadingBlanks = calendar.component(.weekday, from: firstDay) - 1
        let dayCount = calendar.range(of: .day, in: .month, for: displayedMonth)!.count

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in 1...dayCount {
            comps.day = day
            days.append(calendar.date(from: comps))
        }
        let remainder = days.count % 7
        if remainder > 0 { days += Array(repeating: nil, count: 7 - remainder) }
        return days
    }

    private func isToday(_ date: Date) -> Bool { calendar.isDateInToday(date) }
    private func isSelected(_ date: Date) -> Bool { calendar.isDate(date, inSameDayAs: selectedDate) }
    private func isPast(_ date: Date) -> Bool { date < calendar.startOfDay(for: Date()) }

    private func select(_ date: Date) {
        let t = calendar.dateComponents([.hour, .minute], from: selectedDate)
        var d = calendar.dateComponents([.year, .month, .day], from: date)
        d.hour = t.hour; d.minute = t.minute
        if let merged = calendar.date(from: d) { selectedDate = merged }
    }

    private func advanceMonth(_ delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = next
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            monthHeader
            weekdayRow
            dayGrid
        }
        .padding(StartPushLayout.cardPadding(layout))
        .background(
            RoundedRectangle(cornerRadius: StartPushLayout.cardCornerRadius(layout), style: .continuous)
                .fill(.white.opacity(StartPushColor.textEditorFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StartPushLayout.cardCornerRadius(layout), style: .continuous)
                .stroke(PushColorPalette.Accent.walnut.opacity(StartPushColor.textEditorStrokeOpacity), lineWidth: 1)
        )
    }

    private var monthHeader: some View {
        HStack {
            calNavButton("chevron.left", enabled: canGoBack) { advanceMonth(-1) }
            Spacer()
            Text(monthTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            Spacer()
            calNavButton("chevron.right", enabled: true) { advanceMonth(1) }
        }
    }

    private func calNavButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(enabled ? PushControlColors.activeForeground : PushControlColors.textTertiary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(enabled ? PushControlColors.activeFill : .clear))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(icon == "chevron.left" ? "Previous month" : "Next month")
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdayHeaders, id: \.self) { header in
                Text(header)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PushControlColors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        let days = daysInGrid
        let rows = days.count / 7
        return VStack(spacing: 2) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col
                        if let date = days[idx] {
                            CalendarDayCell(
                                day: calendar.component(.day, from: date),
                                isToday: isToday(date),
                                isSelected: isSelected(date),
                                isPast: isPast(date)
                            ) { select(date) }
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: StartPushLayout.calDayCellSize)
                        }
                    }
                }
            }
        }
    }
}

private struct CalendarDayCell: View {
    let day: Int
    let isToday: Bool
    let isSelected: Bool
    let isPast: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? PushControlColors.activeFill : .clear)
                    .frame(width: StartPushLayout.calDayCircle, height: StartPushLayout.calDayCircle)
                if isToday && !isSelected {
                    Circle()
                        .stroke(PushColorPalette.Accent.walnut.opacity(0.35), lineWidth: 1.5)
                        .frame(width: StartPushLayout.calDayCircle, height: StartPushLayout.calDayCircle)
                }
                Text("\(day)")
                    .font(.subheadline.weight(isSelected || isToday ? .bold : .regular))
                    .foregroundStyle(textColor)
            }
            .frame(maxWidth: .infinity, minHeight: StartPushLayout.calDayCellSize)
        }
        .buttonStyle(.plain)
        .disabled(isPast)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isSelected)
        .accessibilityLabel("Day \(day)")
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private var textColor: Color {
        if isSelected { return PushControlColors.activeForeground }
        if isPast { return PushControlColors.textTertiary.opacity(0.4) }
        if isToday { return PushControlColors.textEspresso }
        return PushControlColors.textSecondary
    }
}

// MARK: - Time Clicker

struct PushTimeClicker: View {
    @Environment(\.pushLayout) private var layout
    @Binding var selectedTime: Date

    private let calendar = Calendar.current

    private var hour: Int {
        let h = calendar.component(.hour, from: selectedTime) % 12
        return h == 0 ? 12 : h
    }

    private var minute: Int { calendar.component(.minute, from: selectedTime) }
    private var isAM: Bool { calendar.component(.hour, from: selectedTime) < 12 }

    var body: some View {
        HStack(spacing: 0) {
            TimeStepperColumn(
                value: "\(hour)",
                onUp: incrementHour,
                onDown: decrementHour
            )
            colonSeparator
            TimeStepperColumn(
                value: String(format: "%02d", minute),
                onUp: incrementMinute,
                onDown: decrementMinute
            )
            Spacer(minLength: 12)
            amPmStack
        }
        .padding(StartPushLayout.cardPadding(layout))
        .background(
            RoundedRectangle(cornerRadius: StartPushLayout.cardCornerRadius(layout), style: .continuous)
                .fill(.white.opacity(StartPushColor.textEditorFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: StartPushLayout.cardCornerRadius(layout), style: .continuous)
                .stroke(PushColorPalette.Accent.walnut.opacity(StartPushColor.textEditorStrokeOpacity), lineWidth: 1)
        )
    }

    private var colonSeparator: some View {
        Text(":")
            .font(.title.weight(.bold))
            .foregroundStyle(PushControlColors.textEspresso)
            .frame(width: 18)
            .offset(y: -2)
    }

    private var amPmStack: some View {
        VStack(spacing: 6) {
            AmPmPillButton(title: "AM", isSelected: isAM) { setIsAM(true) }
            AmPmPillButton(title: "PM", isSelected: !isAM) { setIsAM(false) }
        }
        .frame(width: StartPushLayout.amPmPillWidth)
    }

    // MARK: Hour / Minute Mutations

    private func incrementHour() { adjustHour((hour % 12) + 1) }
    private func decrementHour() { adjustHour(hour == 1 ? 12 : hour - 1) }

    private func incrementMinute() {
        let next = [0, 15, 30, 45].first(where: { $0 > minute }) ?? 0
        adjustMinute(next)
    }

    private func decrementMinute() {
        let prev = [0, 15, 30, 45].last(where: { $0 < minute }) ?? 45
        adjustMinute(prev)
    }

    private func adjustHour(_ newHour: Int) {
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedTime)
        let h24 = isAM ? (newHour == 12 ? 0 : newHour) : (newHour == 12 ? 12 : newHour + 12)
        comps.hour = h24
        if let date = calendar.date(from: comps) { selectedTime = date }
    }

    private func adjustMinute(_ newMinute: Int) {
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedTime)
        comps.minute = newMinute
        if let date = calendar.date(from: comps) { selectedTime = date }
    }

    private func setIsAM(_ am: Bool) {
        guard am != isAM else { return }
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedTime)
        let h = comps.hour ?? 0
        comps.hour = am ? h - 12 : h + 12
        if let date = calendar.date(from: comps) { selectedTime = date }
    }
}

private struct TimeStepperColumn: View {
    let value: String
    let onUp: () -> Void
    let onDown: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            stepChevron("chevron.up", action: onUp)
            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
                .monospacedDigit()
                .frame(width: StartPushLayout.timeColumnWidth, height: StartPushLayout.timeValueHeight)
            stepChevron("chevron.down", action: onDown)
        }
        .frame(width: StartPushLayout.timeColumnWidth)
    }

    private func stepChevron(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(width: StartPushLayout.timeChevronWidth, height: StartPushLayout.timeChevronHeight)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PushControlColors.activeFill)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon == "chevron.up" ? "Increase" : "Decrease")
    }
}

private struct AmPmPillButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        PushModalChoicePill(title: title, isSelected: isSelected, action: action)
    }
}
