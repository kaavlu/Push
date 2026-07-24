//
//  PushGlassRimButton.swift
//  Push
//
//  DS-002 glass + walnut-rim primary CTA — e.g. Plans “Start Push”.
//

import SwiftUI

/// Glass capsule with a stronger walnut rim. The second approved primary style
/// alongside `PushSolidSunbeamButton`.
struct PushGlassRimButton: View {
    @Environment(\.pushLayout) private var layout

    let title: String
    var systemImageName: String? = nil
    var accessibilityLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PushGlassRimButtonMetrics.iconTitleSpacing) {
                if let systemImageName {
                    Image(systemName: systemImageName)
                        .font(.system(
                            size: PushGlassRimButtonMetrics.iconSize,
                            weight: .bold
                        ))
                }
                Text(title)
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(PushColorPalette.Accent.walnut)
            .padding(.horizontal, PlansLayout.startPlanButtonHorizontalPadding(layout))
            .frame(height: PlansLayout.startPlanButtonHeight)
            .background {
                Capsule()
                    .fill(PlansColor.primaryGlow)
                    .blur(radius: PushGlassRimButtonMetrics.glowBlurRadius)
                    .padding(.horizontal, PushGlassRimButtonMetrics.glowHorizontalInset)
                    .padding(.vertical, PushGlassRimButtonMetrics.glowVerticalInset)
            }
            .pushGlassBackground(cornerRadius: PlansLayout.startPlanButtonCornerRadius)
            .overlay {
                RoundedRectangle(
                    cornerRadius: PlansLayout.startPlanButtonCornerRadius,
                    style: .continuous
                )
                .stroke(
                    PlansColor.startButtonBorder,
                    lineWidth: PlansColor.startButtonBorderWidth
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}

private enum PushGlassRimButtonMetrics {
    static let iconTitleSpacing: CGFloat = 7
    static let iconSize: CGFloat = 17
    static let glowBlurRadius: CGFloat = 16
    static let glowHorizontalInset: CGFloat = 10
    static let glowVerticalInset: CGFloat = 8
}

#if DEBUG
struct PushGlassRimButton_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            PushGlassRimButton(
                title: "Start Push",
                systemImageName: "plus.circle.fill",
                accessibilityLabel: "Start a new push",
                action: {}
            )
            .padding()
            .background(FriendsColor.pageIvory)
        }
    }
}
#endif
