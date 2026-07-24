//
//  PushTypographyTokens.swift
//  Push
//
//  DS-078 — shared type helpers (section label + rounded initials rules).
//

import SwiftUI

enum PushTypographyTokens {
    /// Uppercase section labels on ivory lists and plan cards.
    static let sectionLabelFont = Font.caption.weight(.bold)
    static let sectionLabelKerning: CGFloat = 0.9

    /// Review deck section labels (slightly larger).
    static let reviewSectionLabelSize: CGFloat = 13
    static let reviewSectionLabelKerning: CGFloat = 0.8

    /// Rounded design is reserved for initials, overflow counts, monospaced time.
    static func initials(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    /// Shared uppercase section-label chrome (Friends/Alerts headers use count badges separately).
    func pushSectionLabelStyle() -> some View {
        font(PushTypographyTokens.sectionLabelFont)
            .kerning(PushTypographyTokens.sectionLabelKerning)
            .foregroundStyle(PushControlColors.textTertiary)
            .textCase(.uppercase)
    }
}
