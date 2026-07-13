//
//  FriendDetailBottomSheet.swift
//  Push
//

import SwiftUI

struct FriendDetailBottomSheet: View {
    @Environment(\.pushLayout) private var layout
    let puck: MapPuckData
    let onDismiss: () -> Void
    let onStartPush: (StartPushLaunchContext) -> Void

    private var sheetHeight: CGFloat {
        switch puck.kind {
        case .individual:
            return FriendDetailSheetLayout.individualSheetHeight(layout)
        case .hangout, .cluster, .friendGroup:
            return FriendDetailSheetLayout.hangoutSheetHeight(layout)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                dismissLayer
                sheetContainer(bottomInset: proxy.safeAreaInsets.bottom)
                    .compositingGroup()
                    .transition(.move(edge: .bottom))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .zIndex(FriendDetailBottomSheetLayout.zIndex)
    }

    private var dismissLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
    }

    private func sheetContainer(bottomInset: CGFloat) -> some View {
        let totalHeight = sheetHeight + bottomInset
        return ZStack(alignment: .top) {
            sheetBackground
            FriendDetailSheet(puck: puck, onStartPush: onStartPush)
                .frame(maxWidth: .infinity, maxHeight: sheetHeight, alignment: .top)
            dragIndicator
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight, alignment: .top)
        .contentShape(Rectangle())
        .gesture(dismissDrag)
        .accessibilityAddTraits(.isModal)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var sheetBackground: some View {
        FriendDetailBottomSheetShape()
            .fill(.ultraThinMaterial)
            .overlay {
                FriendDetailBottomSheetShape()
                    .fill(sheetGradient)
            }
    }

    private var sheetGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: PushColorPalette.Accent.sunbeam.opacity(0.38), location: 0.0),
                .init(color: PushColorPalette.Accent.sunbeam.opacity(0.08), location: 0.25),
                .init(color: Color.clear, location: 0.45),
                .init(color: PushColorPalette.Accent.walnut.opacity(0.08), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var dragIndicator: some View {
        Capsule()
            .fill(PushColorPalette.Accent.walnut.opacity(FriendDetailBottomSheetLayout.indicatorOpacity))
            .frame(
                width: FriendDetailBottomSheetLayout.indicatorWidth,
                height: FriendDetailBottomSheetLayout.indicatorHeight
            )
            .padding(.top, FriendDetailBottomSheetLayout.indicatorTopPadding)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: FriendDetailBottomSheetLayout.dragMinimumDistance)
            .onEnded { value in
                if value.translation.height > FriendDetailBottomSheetLayout.dismissTranslation {
                    onDismiss()
                }
            }
    }
}

private struct FriendDetailBottomSheetShape: Shape {
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

enum FriendDetailBottomSheetLayout {
    static let indicatorWidth: CGFloat = 36
    static let indicatorHeight: CGFloat = 5
    static let indicatorTopPadding: CGFloat = 8
    static let indicatorOpacity: CGFloat = 0.26
    static let dragMinimumDistance: CGFloat = 12
    static let dismissTranslation: CGFloat = 44
    static let animationResponse = 0.38
    static let animationDamping = 0.88
    static let animationBlendDuration = 0.08
    static let zIndex: Double = 30
}
