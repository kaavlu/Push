//
//  PushPuckGlass.swift
//  Push
//
//  DS-012 — puck glass for map annotations only (cooler white tint).
//

import SwiftUI

enum PushPuckGlassTokens {
    static let tintOpacity = 0.16
    static let strokeOpacity = 0.64
    static let strokeWidth: CGFloat = 0.9
}

extension View {
    /// Annotation-scoped glass. Do not use for buttons, cards, or general chrome.
    func pushPuckGlass(cornerRadius: CGFloat) -> some View {
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(PushPuckGlassTokens.tintOpacity))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    .white.opacity(PushPuckGlassTokens.strokeOpacity),
                    lineWidth: PushPuckGlassTokens.strokeWidth
                )
        }
    }
}
