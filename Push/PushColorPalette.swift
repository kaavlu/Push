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
