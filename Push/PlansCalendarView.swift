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

            if viewModel.showsHistoryLink {
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
        day.pushCount > 0
    }

    private var calendarFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.weekFooterPrimaryText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
            if viewModel.showsMostActiveGroup {
                Text("Most active: \(viewModel.mostActiveGroup)")
                    .font(.footnote)
                    .foregroundStyle(PlansColor.metadata)
            }
            if viewModel.showsBestDay, let bestDay = viewModel.bestDayThisWeek {
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

