//
//  PushGlassStyle.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI

enum PushGlassStyle {
    static let materialPresenceOpacity = 0.72
    static let tintOpacity = 0.24
    static let strokeOpacity = 0.62
    static let strokeWidth: CGFloat = 0.8
    static let shadowOpacity = 0.24
    static let shadowRadius: CGFloat = 26
    static let shadowYOffset: CGFloat = 12
}

enum PushControlStyle {
    static let activeFillOpacity = 1.0
    static let inactiveForegroundOpacity = 0.7
    static let primaryStrokeOpacity = 0.72
    static let primaryGlowOpacity = 0.34
}

enum PushControlColors {
    static let activeForeground = PushColorPalette.Accent.walnut
    static let inactiveForeground = PushColorPalette.Accent.walnut.opacity(PushControlStyle.inactiveForegroundOpacity)
    static let activeFill = PushColorPalette.Accent.sunbeam.opacity(PushControlStyle.activeFillOpacity)
}

extension View {
    @ViewBuilder
    func pushGlassBackground(cornerRadius: CGFloat) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            pushMaterialBackground(cornerRadius: cornerRadius)
        }
        #else
        pushMaterialBackground(cornerRadius: cornerRadius)
        #endif
    }

    func pushMaterialBackground(cornerRadius: CGFloat) -> some View {
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial.opacity(PushGlassStyle.materialPresenceOpacity))
        )
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(PushGlassStyle.tintOpacity))
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    .white.opacity(PushGlassStyle.strokeOpacity),
                    lineWidth: PushGlassStyle.strokeWidth
                )
        }
        .shadow(
            color: .black.opacity(PushGlassStyle.shadowOpacity),
            radius: PushGlassStyle.shadowRadius,
            y: PushGlassStyle.shadowYOffset
        )
    }
}
