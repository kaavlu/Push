//
//  PushModalFlowChrome.swift
//  Push
//
//  DS-061 — modal flow close bar / icon button chrome for fullScreenCover flows.
//

import SwiftUI

enum PushModalFlowChromeMetrics {
    static let closeTopPadding: CGFloat = 16
    static let closeBottomPadding: CGFloat = 12
}

/// Trailing close circle on modal gradient flows (Profile, owned pushes, etc.).
struct PushModalCloseButtonBar: View {
    @Environment(\.pushLayout) private var layout
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            PushCircleIconButton(
                systemImageName: "xmark",
                accessibilityLabel: accessibilityLabel,
                action: action
            )
        }
        .padding(.horizontal, layout.pageHorizontalPadding)
        .padding(.top, PushModalFlowChromeMetrics.closeTopPadding)
        .padding(.bottom, PushModalFlowChromeMetrics.closeBottomPadding)
    }
}

/// Migration shim mapping `symbolName` → `PushCircleIconButton` (DS-001).
struct PushModalIconButton: View {
    let symbolName: String
    let accessibilityLabel: String
    var foreground: Color = PushControlColors.activeForeground
    let action: () -> Void

    var body: some View {
        PushCircleIconButton(
            systemImageName: symbolName,
            accessibilityLabel: accessibilityLabel,
            foreground: foreground,
            action: action
        )
    }
}
