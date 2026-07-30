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
    var systemImageName: String? = nil
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    private var showsAsEnabled: Bool {
        isEnabled && !isLoading
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                labelContent
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
                            PushOpacityTokens.disabledControlFill
                        )
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .animation(PushMotion.press, value: showsAsEnabled)
        .animation(PushMotion.press, value: isLoading)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var labelContent: some View {
        if let systemImageName {
            HStack(spacing: PushSolidSunbeamButtonMetrics.iconTitleSpacing) {
                Image(systemName: systemImageName)
                    .font(.system(
                        size: PushSolidSunbeamButtonMetrics.iconSize,
                        weight: .bold
                    ))
                Text(title)
            }
        } else {
            Text(title)
        }
    }
}

private enum PushSolidSunbeamButtonMetrics {
    static let iconTitleSpacing: CGFloat = 7
    static let iconSize: CGFloat = 16
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
