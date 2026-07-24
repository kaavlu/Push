//
//  PushSolidSunbeamButton.swift
//  Push
//
//  DS-002 solid sunbeam primary CTA — multi-step flows + recovery actions (DS-003).
//

import SwiftUI

/// Solid sunbeam capsule primary. Pair with `PushGlassRimButton` for the only
/// two approved in-app primary treatments (no third style without a DS decision).
struct PushSolidSunbeamButton: View {
    @Environment(\.pushLayout) private var layout

    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    private var showsAsEnabled: Bool {
        isEnabled && !isLoading
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .tint(PushControlColors.activeForeground)
                }
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(
                showsAsEnabled
                    ? PushControlColors.activeForeground
                    : PushControlColors.inactiveForeground
            )
            .frame(maxWidth: .infinity)
            .frame(height: layout.primaryButtonHeight)
            .background(
                Capsule().fill(
                    showsAsEnabled
                        ? PushControlColors.activeFill
                        : PushControlColors.activeFill.opacity(
                            PushSolidSunbeamButtonMetrics.disabledFillOpacity
                        )
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .animation(
            .easeInOut(duration: PushSolidSunbeamButtonMetrics.stateAnimationDuration),
            value: showsAsEnabled
        )
        .animation(
            .easeInOut(duration: PushSolidSunbeamButtonMetrics.stateAnimationDuration),
            value: isLoading
        )
        .accessibilityLabel(title)
    }
}

private enum PushSolidSunbeamButtonMetrics {
    static let disabledFillOpacity = 0.45
    static let stateAnimationDuration = 0.18
}

/// Migration shim — prefer `PushSolidSunbeamButton`.
typealias StartPushPrimaryButton = PushSolidSunbeamButton

#if DEBUG
struct PushSolidSunbeamButton_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            VStack(spacing: 16) {
                PushSolidSunbeamButton(title: "Next", isEnabled: true, action: {})
                PushSolidSunbeamButton(title: "Disabled", isEnabled: false, action: {})
                PushSolidSunbeamButton(title: "Saving…", isLoading: true, action: {})
            }
            .padding()
            .background(PushModalBackground())
        }
    }
}
#endif
