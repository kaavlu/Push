//
//  PushColorPalette.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/28/26.
//

import SwiftUI

enum PushColorPalette {
    enum Accent {
        static let sunbeam = Color(hex: 0xFFEE8C)
        static let walnut = Color(hex: 0x8B5B29)
        static let sageGreen = Color(hex: 0x2E7A47)
        static let mintFoam = Color(hex: 0xC7F0D6)
    }

    enum Onboarding {
        static let screenTop = Color(hex: 0xFFF3A6)
        static let screenMiddle = Accent.sunbeam
        static let screenBottom = Color(hex: 0xFFE87C)
        static let ctaTop = Color(hex: 0x4A2C12)
        static let ctaBottom = Color(hex: 0x331B0A)
        static let ctaLabel = Color(hex: 0xFFF3D6)
        static let fieldFill = Color.white.opacity(0.55)
        static let keyFill = Color.white.opacity(0.50)
        static let keyFillActive = Color.white.opacity(0.85)
        static let glassTint = Color(hex: 0xFFF2D6).opacity(0.28)
        static let miniMapTop = Color(hex: 0xE9F4E1)
        static let miniMapBottom = Color(hex: 0xFBF1D3)
        static let notificationBadge = Color(hex: 0xFF5A3C)
        static let purpleAccent = Color(hex: 0x7D63C9)
        static let freeNowText = Color(hex: 0x0A4D29)
        static let drivingText = Color(hex: 0x054D6B)
        static let appleButtonFill = Color(hex: 0x1A1206)
        static let googleButtonText = Color(hex: 0x3C3C3C)
    }
}

private extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> HexColorComponent.redShift) & HexColorComponent.mask) / HexColorComponent.divisor,
            green: Double((hex >> HexColorComponent.greenShift) & HexColorComponent.mask) / HexColorComponent.divisor,
            blue: Double(hex & HexColorComponent.mask) / HexColorComponent.divisor,
            opacity: opacity
        )
    }
}

private enum HexColorComponent {
    static let redShift: UInt32 = 16
    static let greenShift: UInt32 = 8
    static let mask: UInt32 = 0xFF
    static let divisor = 255.0
}
