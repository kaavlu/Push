//
//  PushMapBottomSheetChrome.swift
//  Push
//
//  DS-064 — map bottom-sheet presentation metrics + drag indicator.
//

import SwiftUI

/// Shared motion / chrome constants for custom map bottom sheets
/// (friend detail, day detail) — not system `.sheet`.
enum PushMapBottomSheetChrome {
    static let indicatorWidth: CGFloat = 36
    static let indicatorHeight: CGFloat = 5
    static let indicatorTopPadding: CGFloat = 8
    static let indicatorOpacity: CGFloat = 0.26
    static let dragMinimumDistance: CGFloat = 12
    static let dismissTranslation: CGFloat = 44
    static let dismissPredictedTranslation: CGFloat = 120
    static let animationResponse = PushMotion.Sheet.response
    static let animationDamping = PushMotion.Sheet.damping
    static let animationBlendDuration = PushMotion.Sheet.blendDuration
    static let dismissAnimationDuration = PushMotion.Sheet.dismissAnimationDuration
    static let presentationOvershoot: CGFloat = 12
    static let closedScale = PushMotion.Sheet.closedScale
    static let zIndex: Double = 30
}

struct PushMapBottomSheetDragIndicator: View {
    var body: some View {
        Capsule()
            .fill(PushColorPalette.Accent.walnut.opacity(PushMapBottomSheetChrome.indicatorOpacity))
            .frame(
                width: PushMapBottomSheetChrome.indicatorWidth,
                height: PushMapBottomSheetChrome.indicatorHeight
            )
            .padding(.top, PushMapBottomSheetChrome.indicatorTopPadding)
    }
}
