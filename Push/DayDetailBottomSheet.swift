//
//  DayDetailBottomSheet.swift
//  Push
//
//  Full-width calendar day popup using the same chrome model as the map
//  friend sheet (not a system `.sheet`, which picks up side insets).
//

import SwiftUI

struct DayDetailBottomSheet: View {
    let day: CalendarDayData
    let onDismiss: () -> Void

    @State private var isSettled = false
    @State private var isDismissing = false
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    private var dayHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: day.date)
    }

    private var presentationAnimation: Animation {
        PushMotion.sheet
    }

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom
            let sheetHeight = DayDetailBottomSheetLayout.contentHeight
            let totalHeight = sheetHeight + bottomInset
            let closedOffset = totalHeight + FriendDetailBottomSheetLayout.presentationOvershoot

            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: animateDismiss)

                sheetCard(sheetHeight: sheetHeight, bottomInset: bottomInset)
                    .compositingGroup()
                    .scaleEffect(
                        isSettled ? 1 : FriendDetailBottomSheetLayout.closedScale,
                        anchor: .bottom
                    )
                    .offset(y: (isSettled ? 0 : closedOffset) + max(0, dragTranslation))
                    .animation(isDragging ? nil : presentationAnimation, value: isSettled)
                    .animation(isDragging ? nil : presentationAnimation, value: dragTranslation)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            DispatchQueue.main.async { isSettled = true }
        }
    }

    private func sheetCard(sheetHeight: CGFloat, bottomInset: CGFloat) -> some View {
        let totalHeight = sheetHeight + bottomInset
        let shape = DayDetailBottomSheetShape()
        return ZStack(alignment: .top) {
            MapPopupSheetBackground(shape: shape)
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(
                        PushColorPalette.Accent.walnut.opacity(
                            FriendDetailBottomSheetLayout.indicatorOpacity
                        )
                    )
                    .frame(
                        width: FriendDetailBottomSheetLayout.indicatorWidth,
                        height: FriendDetailBottomSheetLayout.indicatorHeight
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, FriendDetailBottomSheetLayout.indicatorTopPadding)

                VStack(alignment: .leading, spacing: 4) {
                    Text(dayHeader)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PushControlColors.textEspresso)
                    pushCountLine
                }
                .padding(.horizontal, DayDetailBottomSheetLayout.horizontalPadding)
                .padding(.top, DayDetailBottomSheetLayout.headerTopPadding)
                .padding(.bottom, DayDetailBottomSheetLayout.headerBottomPadding)

                if !day.hangouts.isEmpty {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: DayDetailBottomSheetLayout.rowSpacing) {
                            ForEach(day.hangouts) { hangout in
                                DayHangoutRow(hangout: hangout)
                            }
                        }
                        .padding(.horizontal, DayDetailBottomSheetLayout.horizontalPadding)
                        .padding(.bottom, DayDetailBottomSheetLayout.contentBottomPadding)
                    }
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: sheetHeight, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight, alignment: .top)
        .clipShape(shape)
        .contentShape(Rectangle())
        .gesture(dismissDrag)
    }

    @ViewBuilder
    private var pushCountLine: some View {
        if day.pushCount == 0 {
            Text("Nothing happened")
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textTertiary)
        } else {
            Text("\(day.pushCount) \(day.pushCount == 1 ? "Push" : "Pushes")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
        }
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: FriendDetailBottomSheetLayout.dragMinimumDistance)
            .onChanged { value in
                guard !isDismissing else { return }
                isDragging = true
                dragTranslation = max(0, value.translation.height)
            }
            .onEnded { value in
                guard !isDismissing else { return }
                isDragging = false
                let shouldDismiss =
                    value.translation.height > FriendDetailBottomSheetLayout.dismissTranslation
                    || value.predictedEndTranslation.height
                        > FriendDetailBottomSheetLayout.dismissPredictedTranslation
                if shouldDismiss {
                    animateDismiss()
                } else {
                    dragTranslation = 0
                }
            }
    }

    private func animateDismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        isDragging = false
        isSettled = false
        DispatchQueue.main.asyncAfter(
            deadline: .now() + FriendDetailBottomSheetLayout.dismissAnimationDuration
        ) {
            onDismiss()
        }
    }
}

// MARK: - Shape / layout

private struct DayDetailBottomSheetShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = FriendDetailSheetLayout.sheetCornerRadius
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private enum DayDetailBottomSheetLayout {
    static let contentHeight: CGFloat = 280
    static let horizontalPadding: CGFloat = 24
    static let headerTopPadding: CGFloat = 12
    static let headerBottomPadding: CGFloat = 16
    static let contentBottomPadding: CGFloat = 24
    static let rowSpacing: CGFloat = 14
}

// MARK: - Hangout rows

private struct DayHangoutRow: View {
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
            DayHistoryPuck(people: hangout.people)
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

// MARK: - History pucks (no live availability chrome)

private enum DayHistoryPuckLayout {
    static let size: CGFloat = 52
    static let pairAvatarScale: CGFloat = 0.60
    static let pairCenterOffsetScale: CGFloat = 0.28
    static let pairRingWidth: CGFloat = 3
    static let groupAvatarScale: CGFloat = 0.50
    static let groupRingWidth: CGFloat = 2.6
    static let groupAvatarOffsets: [CGSize] = [
        CGSize(width: -0.28, height: -0.20),
        CGSize(width: 0.28, height: -0.20),
        CGSize(width: 0.00, height: 0.28)
    ]
    static let ringStrokeOpacity: CGFloat = 0.72
}

private struct DayHistoryPuck: View {
    let people: [HangoutPerson]

    var body: some View {
        switch people.count {
        case 0:
            Color.clear
                .frame(width: DayHistoryPuckLayout.size, height: DayHistoryPuckLayout.size)
        case 1:
            DaySoloHistoryPuck(person: people[0])
        case 2:
            DayPairHistoryPuck(people: Array(people.prefix(2)))
        default:
            DayGroupHistoryPuck(people: Array(people.prefix(3)))
        }
    }
}

private struct DaySoloHistoryPuck: View {
    let person: HangoutPerson
    private let size = DayHistoryPuckLayout.size

    var body: some View {
        ProfilePhotoAvatar(
            imageAssetName: person.imageAssetName,
            fallbackInitials: person.initials
        )
        .frame(width: size, height: size)
        .puckGlassBackground(cornerRadius: size / FriendPuckLayout.cornerDivisor)
    }
}

private struct DayPairHistoryPuck: View {
    let people: [HangoutPerson]
    private let size = DayHistoryPuckLayout.size
    private var avatarSize: CGFloat { size * DayHistoryPuckLayout.pairAvatarScale }
    private var centerOffset: CGFloat { avatarSize * DayHistoryPuckLayout.pairCenterOffsetScale }

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
                            .white.opacity(DayHistoryPuckLayout.ringStrokeOpacity),
                            lineWidth: DayHistoryPuckLayout.pairRingWidth
                        )
                }
                .offset(x: index == 0 ? -centerOffset : centerOffset)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct DayGroupHistoryPuck: View {
    let people: [HangoutPerson]
    private let size = DayHistoryPuckLayout.size
    private var avatarSize: CGFloat { size * DayHistoryPuckLayout.groupAvatarScale }

    private func offset(for index: Int) -> CGSize {
        let base = DayHistoryPuckLayout.groupAvatarOffsets
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
                            .white.opacity(DayHistoryPuckLayout.ringStrokeOpacity),
                            lineWidth: DayHistoryPuckLayout.groupRingWidth
                        )
                }
                .offset(offset(for: index))
            }
        }
        .frame(width: size, height: size)
    }
}
