// Push/PlansWeeklyRecapDayTile.swift
import SwiftUI

struct WeeklyRecapDayTile: View {
    let day: CalendarDayData
    let isSelected: Bool
    let opensDetail: Bool
    let onTap: () -> Void

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    private var isEmphasized: Bool {
        isToday || isSelected
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: WeeklyRecapTileLayout.labelSpacing) {
                Text(weekdayLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(weekdayTextColor)
                Text(dayNumber)
                    .font(.subheadline.weight(isEmphasized ? .bold : .semibold))
                    .foregroundStyle(dayTextColor)
                activityTile
                    .padding(.top, WeeklyRecapTileLayout.dateToTileTopPadding)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(opensDetail)
        .accessibilityLabel(accessibilityLabel)
    }

    private var activityTile: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: WeeklyRecapTileLayout.tileCornerRadius)
                .fill(tileBackground)
                .overlay(tileStroke)
                .overlay(liquidHighlight)
                .shadow(
                    color: glowColor.opacity(shadowOpacity),
                    radius: WeeklyRecapTileLayout.shadowRadius,
                    x: 0,
                    y: WeeklyRecapTileLayout.shadowYOffset
                )

            if day.pushCount > 0 {
                activityHeat
            }
        }
        .frame(height: WeeklyRecapTileLayout.tileHeight)
    }

    private var tileStroke: some View {
        RoundedRectangle(cornerRadius: WeeklyRecapTileLayout.tileCornerRadius)
            .stroke(strokeColor, lineWidth: WeeklyRecapTileLayout.strokeWidth)
    }

    private var liquidHighlight: some View {
        RoundedRectangle(cornerRadius: WeeklyRecapTileLayout.tileCornerRadius)
            .stroke(
                LinearGradient(
                    colors: [
                        PlansColor.creamBase.opacity(0.48),
                        PushColorPalette.Accent.sunbeam.opacity(0.20),
                        PushColorPalette.Accent.walnut.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: WeeklyRecapTileLayout.highlightStrokeWidth
            )
            .padding(WeeklyRecapTileLayout.highlightInset)
    }

    private var activityHeat: some View {
        ZStack(alignment: .bottom) {
            activityGlow
            heatBars
        }
        .padding(WeeklyRecapTileLayout.innerPadding)
    }

    private var activityGlow: some View {
        RoundedRectangle(cornerRadius: WeeklyRecapTileLayout.innerCornerRadius)
            .fill(glowGradient)
            .frame(height: activityHeight)
            .blur(radius: WeeklyRecapTileLayout.glowBlur)
            .opacity(glowOpacity)
    }

    private var heatBars: some View {
        VStack(spacing: WeeklyRecapTileLayout.heatBarSpacing) {
            ForEach(0..<heatBarCount, id: \.self) { index in
                heatBar(for: index)
            }
        }
        .padding(.bottom, WeeklyRecapTileLayout.heatBarBottomPadding)
    }

    private func heatBar(for index: Int) -> some View {
        Capsule()
            .fill(heatBarGradient(for: index))
            .frame(
                width: heatBarWidth(for: index),
                height: WeeklyRecapTileLayout.heatBarHeight
            )
            .shadow(
                color: heatBarShadowColor(for: index),
                radius: heatBarShadowRadius(for: index),
                x: 0,
                y: WeeklyRecapTileLayout.heatBarShadowYOffset
            )
    }

    private var weekdayLabel: String {
        formatted("E").uppercased()
    }

    private var dayNumber: String {
        formatted("d")
    }

    private var dayTextColor: Color {
        PushControlColors.textEspresso
    }

    private var weekdayTextColor: Color {
        PushControlColors.textEspresso
    }

    private var tileBackground: LinearGradient {
        LinearGradient(
            colors: tileBackgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var tileBackgroundColors: [Color] {
        if isEmphasized {
            return [
                PushColorPalette.Accent.sunbeam.opacity(0.24),
                PlansColor.creamBase.opacity(0.42),
                PushColorPalette.Accent.walnut.opacity(0.07)
            ]
        }
        if day.pushCount > 0 {
            return [
                PlansColor.creamBase.opacity(0.34),
                PushColorPalette.Accent.sunbeam.opacity(0.15),
                PushColorPalette.Accent.walnut.opacity(0.07)
            ]
        }
        return [
            PlansColor.creamBase.opacity(0.24),
            PlansColor.creamSoft.opacity(0.16),
            PushColorPalette.Accent.walnut.opacity(0.065)
        ]
    }

    private var strokeColor: Color {
        if isEmphasized { return PushColorPalette.Accent.walnut.opacity(0.24) }
        if day.pushCount > 0 { return PushColorPalette.Accent.walnut.opacity(0.18) }
        return PushColorPalette.Accent.walnut.opacity(0.18)
    }

    private var glowColor: Color {
        day.pushCount > 0 || isEmphasized
            ? PushColorPalette.Accent.sunbeam
            : PushColorPalette.Accent.walnut
    }

    private var shadowOpacity: Double {
        if isEmphasized { return 0.32 }
        return day.pushCount > 0 ? min(0.14 + Double(day.pushCount) * 0.05, 0.34) : 0.04
    }

    private var activityHeight: CGFloat {
        let cappedCount = min(day.pushCount, WeeklyRecapTileLayout.maxPushCount)
        return CGFloat(cappedCount) * WeeklyRecapTileLayout.activityHeightUnit
            + WeeklyRecapTileLayout.activityBaseHeight
    }

    private var glowOpacity: Double {
        min(0.30 + Double(day.pushCount) * 0.12, 0.78)
    }

    private var glowGradient: LinearGradient {
        LinearGradient(
            colors: [
                PushColorPalette.Accent.sunbeam.opacity(0.86),
                PushColorPalette.Accent.sunbeam.opacity(0.42),
                PushColorPalette.Accent.walnut.opacity(0.24)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var heatBarCount: Int {
        max(1, min(day.pushCount, WeeklyRecapTileLayout.maxHeatBarCount))
    }

    private func heatBarGradient(for index: Int) -> LinearGradient {
        LinearGradient(
            colors: [
                PlansColor.creamBase.opacity(index == 0 ? 0.92 : 0.68),
                PushColorPalette.Accent.sunbeam.opacity(0.92),
                PushColorPalette.Accent.walnut.opacity(index == 0 ? 0.40 : 0.30)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func heatBarWidth(for index: Int) -> CGFloat {
        WeeklyRecapTileLayout.heatBarBaseWidth
            + CGFloat(heatBarCount - index) * WeeklyRecapTileLayout.heatBarWidthStep
    }

    private func heatBarShadowOpacity(for index: Int) -> Double {
        max(0.30, 0.56 - Double(index) * 0.05)
    }

    private func heatBarShadowColor(for index: Int) -> Color {
        PushColorPalette.Accent.sunbeam.opacity(heatBarShadowOpacity(for: index))
    }

    private func heatBarShadowRadius(for index: Int) -> CGFloat {
        WeeklyRecapTileLayout.heatBarShadowRadius + CGFloat(max(0, heatBarCount - index - 1))
    }

    private func formatted(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: day.date)
    }

    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: day.date)), \(day.pushCount) pushes"
    }
}

private enum WeeklyRecapTileLayout {
    static let labelSpacing: CGFloat = 3
    static let dateToTileTopPadding: CGFloat = 3
    static let tileHeight: CGFloat = 58
    static let tileCornerRadius: CGFloat = 15
    static let innerCornerRadius: CGFloat = 11
    static let innerPadding: CGFloat = 5
    static let strokeWidth: CGFloat = 1
    static let shadowRadius: CGFloat = 11
    static let shadowYOffset: CGFloat = 4
    static let highlightStrokeWidth: CGFloat = 0.8
    static let highlightInset: CGFloat = 1
    static let heatBarHeight: CGFloat = 5
    static let heatBarBaseWidth: CGFloat = 9
    static let heatBarWidthStep: CGFloat = 4
    static let heatBarSpacing: CGFloat = 4
    static let heatBarBottomPadding: CGFloat = 8
    static let heatBarShadowRadius: CGFloat = 5
    static let heatBarShadowYOffset: CGFloat = 1
    static let maxPushCount = 5
    static let maxHeatBarCount = 5
    static let activityBaseHeight: CGFloat = 7
    static let activityHeightUnit: CGFloat = 8
    static let glowBlur: CGFloat = 7
}
