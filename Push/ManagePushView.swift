// Push/ManagePushView.swift
import SwiftUI

struct ManagePushView: View {
    @Environment(\.pushLayout) private var layout
    let plan: PlanData
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            PushModalBackground()
            VStack(spacing: PlansLayout.sectionSpacing(layout)) {
                Text(plan.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                Text("Manage coming soon")
                    .font(.subheadline)
                    .foregroundStyle(PushControlColors.textTertiary)
            }
        }
        .overlay(alignment: .top) {
            PushModalCloseButtonBar(accessibilityLabel: "Close manage push") {
                onDismiss()
            }
        }
    }
}
