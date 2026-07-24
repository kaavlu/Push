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

    /// `false` → sheet sits just below the screen; `true` → settled open.
    /// Animating this value (not a full-screen transition) keeps glass hangout
    /// actions glued to the chrome while still giving a springy slide.
    @State private var isSettled = false
    @State private var isDismissing = false
    /// Interactive drag-to-dismiss translation (down only). Tracks 1:1; springs
    /// only when released back open.
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    private var sheetHeight: CGFloat {
        switch puck.kind {
        case .individual:
            return FriendDetailSheetLayout.individualSheetHeight(layout)
        case .hangout, .cluster, .friendGroup:
            return FriendDetailSheetLayout.hangoutSheetHeight(layout)
        }
    }

    private var presentationAnimation: Animation {
        PushMotion.sheet
    }

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom
            let totalHeight = sheetHeight + bottomInset
            let closedOffset = totalHeight + FriendDetailBottomSheetLayout.presentationOvershoot

            ZStack(alignment: .bottom) {
                dismissLayer

                sheetContainer(bottomInset: bottomInset)
                    .compositingGroup()
                    .scaleEffect(
                        presentationScale,
                        anchor: .bottom
                    )
                    .offset(y: sheetOffset(closedOffset: closedOffset))
                    // Spring open/close + snap-back. Drag updates skip this path
                    // via `isDragging` so the card follows the finger directly.
                    .animation(isDragging ? nil : presentationAnimation, value: isSettled)
                    .animation(isDragging ? nil : presentationAnimation, value: dragTranslation)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .zIndex(FriendDetailBottomSheetLayout.zIndex)
        .onAppear(perform: presentSheet)
    }

    private var presentationScale: CGFloat {
        if isSettled { return 1 }
        return FriendDetailBottomSheetLayout.closedScale
    }

    private func sheetOffset(closedOffset: CGFloat) -> CGFloat {
        let base = isSettled ? 0 : closedOffset
        return base + max(0, dragTranslation)
    }

    private var dismissLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(perform: animateDismiss)
    }

    private func sheetContainer(bottomInset: CGFloat) -> some View {
        let totalHeight = sheetHeight + bottomInset
        return ZStack(alignment: .top) {
            sheetBackground
            // Top-align so any extra sheet height sits under the action row
            // (not above content near the drag handle). Bottom padding is shared
            // via `FriendDetailSheetLayout.actionBottomPadding`.
            FriendDetailSheet(puck: puck, onStartPush: handleStartPush)
                .frame(maxWidth: .infinity, maxHeight: sheetHeight, alignment: .top)
            dragIndicator
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight, alignment: .top)
        .clipShape(FriendDetailBottomSheetShape())
        .contentShape(Rectangle())
        .gesture(dismissDrag)
        .accessibilityAddTraits(.isModal)
    }

    private var sheetBackground: some View {
        MapPopupSheetBackground(shape: FriendDetailBottomSheetShape())
    }

    private var dragIndicator: some View {
        PushMapBottomSheetDragIndicator()
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
                    || value.predictedEndTranslation.height > FriendDetailBottomSheetLayout.dismissPredictedTranslation
                if shouldDismiss {
                    animateDismiss()
                } else {
                    dragTranslation = 0
                }
            }
    }

    private func presentSheet() {
        guard !isSettled else { return }
        // One laid-out off-screen frame, then spring open — same idea as the
        // create menu: slide + soft scale from the bottom edge.
        DispatchQueue.main.async {
            isSettled = true
        }
    }

    private func animateDismiss() {
        beginDismiss {
            onDismiss()
        }
    }

    private func handleStartPush(_ context: StartPushLaunchContext) {
        beginDismiss {
            onDismiss()
            onStartPush(context)
        }
    }

    private func beginDismiss(completion: @escaping () -> Void) {
        guard !isDismissing else { return }
        isDismissing = true
        // Keep any in-progress drag offset so close continues downward from the
        // finger position instead of snapping back to fully open first.
        isDragging = false
        guard isSettled else {
            completion()
            return
        }
        isSettled = false
        DispatchQueue.main.asyncAfter(
            deadline: .now() + FriendDetailBottomSheetLayout.dismissAnimationDuration
        ) {
            completion()
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
    /// Prefer `PushMapBottomSheetChrome` for new map sheets (DS-064).
    static let indicatorWidth = PushMapBottomSheetChrome.indicatorWidth
    static let indicatorHeight = PushMapBottomSheetChrome.indicatorHeight
    static let indicatorTopPadding = PushMapBottomSheetChrome.indicatorTopPadding
    static let indicatorOpacity = PushMapBottomSheetChrome.indicatorOpacity
    static let dragMinimumDistance = PushMapBottomSheetChrome.dragMinimumDistance
    static let dismissTranslation = PushMapBottomSheetChrome.dismissTranslation
    static let dismissPredictedTranslation = PushMapBottomSheetChrome.dismissPredictedTranslation
    static let animationResponse = PushMapBottomSheetChrome.animationResponse
    static let animationDamping = PushMapBottomSheetChrome.animationDamping
    static let animationBlendDuration = PushMapBottomSheetChrome.animationBlendDuration
    static let dismissAnimationDuration = PushMapBottomSheetChrome.dismissAnimationDuration
    static let presentationOvershoot = PushMapBottomSheetChrome.presentationOvershoot
    static let closedScale = PushMapBottomSheetChrome.closedScale
    static let zIndex = PushMapBottomSheetChrome.zIndex

    static let strokeWidth = PushMapGlassTokens.sheetStrokeWidth
    static let highlightWidth = PushMapGlassTokens.sheetHighlightWidth
    static let highlightInset = PushMapGlassTokens.sheetHighlightInset
    static let sunbeamGlowRadius = PushMapGlassTokens.sheetSunbeamGlowRadius
}

/// Prefer `PushMapGlassTokens` for map sheet surface chrome (DS-011).
enum FriendDetailBottomSheetColor {
    static let creamFill = PushMapGlassTokens.sheetCreamFill
    static let creamGlowOpacity = PushMapGlassTokens.sheetCreamGlowOpacity
    static let sunbeamGlowOpacity = PushMapGlassTokens.sheetSunbeamGlowOpacity
    static let stroke = PushMapGlassTokens.sheetStroke
    static let highlightTopOpacity = PushMapGlassTokens.sheetHighlightTopOpacity
    static let highlightSideOpacity = PushMapGlassTokens.sheetHighlightSideOpacity
}

// MapPopupSheetBackground lives in DesignSystem/Surfaces/PushMapGlass.swift.
