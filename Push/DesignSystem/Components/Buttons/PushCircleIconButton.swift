//
//  PushCircleIconButton.swift
//  Push
//
//  DS-001 — generic circular utility (close, header actions, trash icon).
//  Same dimensions + control glass; symbol and a11y label vary.
//

import SwiftUI

enum PushCircleIconButtonMetrics {
    static let size: CGFloat = 44
    static let iconSize: CGFloat = 14
    static let iconWeight: Font.Weight = .bold
}

/// Shared glass circular icon control for generic nav/utility actions.
///
/// Use for same-size close / header / trash circles. Do **not** use for map
/// profile controls, bottom-nav center +, or create-menu sunbeam icons (DS-007).
struct PushCircleIconButton: View {
    let systemImageName: String
    let accessibilityLabel: String
    var foreground: Color = PushControlColors.activeForeground
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImageName)
                .font(.system(
                    size: PushCircleIconButtonMetrics.iconSize,
                    weight: PushCircleIconButtonMetrics.iconWeight
                ))
                .foregroundStyle(foreground)
                .frame(
                    width: PushCircleIconButtonMetrics.size,
                    height: PushCircleIconButtonMetrics.size
                )
                .pushGlassBackground(cornerRadius: PushCircleIconButtonMetrics.size / 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Migration shim — prefer `PushCircleIconButton`.
typealias FriendsCircleButton = PushCircleIconButton

#if DEBUG
struct PushCircleIconButton_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            HStack(spacing: 16) {
                PushCircleIconButton(
                    systemImageName: "xmark",
                    accessibilityLabel: "Close",
                    action: {}
                )
                PushCircleIconButton(
                    systemImageName: "plus",
                    accessibilityLabel: "Add",
                    action: {}
                )
                PushCircleIconButton(
                    systemImageName: "trash",
                    accessibilityLabel: "Delete",
                    foreground: PushControlColors.destructive,
                    action: {}
                )
            }
            .padding()
            .background(FriendsColor.pageIvory)
        }
    }
}
#endif
