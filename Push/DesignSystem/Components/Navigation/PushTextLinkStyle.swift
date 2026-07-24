//
//  PushTextLinkStyle.swift
//  Push
//
//  DS-062 — text link style for secondary actions on cream pages.
//

import SwiftUI

enum PushTextLinkMetrics {
    static let font = Font.subheadline.weight(.semibold)
}

extension Text {
    /// Walnut text-link treatment (e.g. Plans “History ›”, “Manage →”).
    func pushTextLinkStyle() -> some View {
        font(PushTextLinkMetrics.font)
            .foregroundStyle(PushColorPalette.Accent.walnut)
    }
}
