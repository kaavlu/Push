//
//  PushControlGlass.swift
//  Push
//
//  DS-010 — generic control glass for floating chrome outside map/puck families.
//

import SwiftUI

/// Internal tokens for generic control glass (iOS 26 glassEffect + warm cream path).
enum PushControlGlassTokens {
    static let materialPresenceOpacity = 0.68
    static let warmTint = Color(red: 1.0, green: 0.95, blue: 0.84)
    static let tintOpacity = 0.22
    static let strokeOpacity = 0.52
    static let strokeWidth: CGFloat = 0.8
    static let shadowColor = Color(red: 0.55, green: 0.36, blue: 0.16)
    static let shadowOpacity = 0.18
    static let shadowRadius: CGFloat = 24
    static let shadowYOffset: CGFloat = 10
}

extension View {
    /// Named generic control glass — circular buttons, bottom nav, create menu,
    /// map empty overlay, toasts, Plans Start Push base glass.
    @ViewBuilder
    func pushControlGlass(cornerRadius: CGFloat, showsShadow: Bool = true) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let base = self
                .background(shape.fill(PushControlGlassTokens.warmTint.opacity(PushControlGlassTokens.tintOpacity)))
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape.stroke(
                        .white.opacity(PushControlGlassTokens.strokeOpacity),
                        lineWidth: PushControlGlassTokens.strokeWidth
                    )
                }
            if showsShadow {
                base.shadow(
                    color: PushControlGlassTokens.shadowColor.opacity(PushControlGlassTokens.shadowOpacity),
                    radius: PushControlGlassTokens.shadowRadius,
                    y: PushControlGlassTokens.shadowYOffset
                )
            } else {
                base
            }
        } else {
            pushControlGlassMaterial(cornerRadius: cornerRadius, showsShadow: showsShadow)
        }
        #else
        pushControlGlassMaterial(cornerRadius: cornerRadius, showsShadow: showsShadow)
        #endif
    }

    @ViewBuilder
    func pushControlGlassMaterial(cornerRadius: CGFloat, showsShadow: Bool = true) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let base = background(.ultraThinMaterial, in: shape)
            .background(
                shape.fill(.regularMaterial.opacity(PushControlGlassTokens.materialPresenceOpacity))
            )
            .background(
                shape.fill(PushControlGlassTokens.warmTint.opacity(PushControlGlassTokens.tintOpacity))
            )
            .overlay {
                shape.stroke(
                    .white.opacity(PushControlGlassTokens.strokeOpacity),
                    lineWidth: PushControlGlassTokens.strokeWidth
                )
            }
        if showsShadow {
            base.shadow(
                color: PushControlGlassTokens.shadowColor.opacity(PushControlGlassTokens.shadowOpacity),
                radius: PushControlGlassTokens.shadowRadius,
                y: PushControlGlassTokens.shadowYOffset
            )
        } else {
            base
        }
    }
}
