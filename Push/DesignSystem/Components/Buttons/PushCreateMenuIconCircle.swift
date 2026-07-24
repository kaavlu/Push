//
//  PushCreateMenuIconCircle.swift
//  Push
//
//  DS-007 — sunbeam-filled icon circle for action-menu rows only.
//

import SwiftUI

/// Menu-scoped sunbeam icon circle. Distinct from `PushCircleIconButton` (glass)
/// and bottom-nav center + (DS-005).
struct PushCreateMenuIconCircle: View {
    @Environment(\.pushLayout) private var layout
    let systemImageName: String

    var body: some View {
        Image(systemName: systemImageName)
            .font(.system(size: CreateActionMenuLayout.iconSize, weight: .bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(
                width: CreateActionMenuLayout.iconFrame(layout),
                height: CreateActionMenuLayout.iconFrame(layout)
            )
            .background(Circle().fill(PushControlColors.activeFill))
    }
}

#if DEBUG
struct PushCreateMenuIconCircle_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            HStack(spacing: 12) {
                PushCreateMenuIconCircle(systemImageName: "person.badge.plus")
                PushCreateMenuIconCircle(systemImageName: "person.3")
                PushCreateMenuIconCircle(systemImageName: "bolt.fill")
            }
            .padding()
            .background(Color.white.opacity(0.3))
        }
    }
}
#endif
