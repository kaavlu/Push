//
//  PushModalSurface.swift
//  Push
//
//  DS-015 — modal gradient for focused full-screen flows.
//

import SwiftUI

enum PushModalSurfaceTokens {
    static let sunbeamTopOpacity = 0.62
    static let walnutBottomOpacity = 0.18
}

/// Sunbeam → white → walnut gradient for enter → complete → exit flows.
struct PushModalBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                PushColorPalette.Accent.sunbeam.opacity(PushModalSurfaceTokens.sunbeamTopOpacity),
                .white,
                PushColorPalette.Accent.walnut.opacity(PushModalSurfaceTokens.walnutBottomOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
