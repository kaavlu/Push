import SwiftUI

struct EmptySurfaceView: View {
    let title: String
    let message: String
    var systemImage: String = "person.2"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: EmptySurfaceLayout.contentSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: EmptySurfaceLayout.iconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textTertiary)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                PushSolidSunbeamButton(title: actionTitle, action: action)
                    .padding(.top, EmptySurfaceLayout.actionTopPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, EmptySurfaceLayout.horizontalPadding)
        .padding(.top, EmptySurfaceLayout.topPadding)
        .accessibilityElement(children: .combine)
    }
}

enum EmptySurfaceStateView {
    static var loading: some View {
        VStack(spacing: EmptySurfaceLayout.contentSpacing) {
            ProgressView().tint(PushControlColors.activeForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    static func loading(message: String) -> some View {
        VStack(spacing: EmptySurfaceLayout.contentSpacing) {
            ProgressView().tint(PushControlColors.activeForeground)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    static func failed(surface: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: EmptySurfaceLayout.contentSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: EmptySurfaceLayout.iconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textSecondary)
            Text(EmptySurfaceCopy.failedTitle(surface: surface))
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text(EmptySurfaceCopy.failedMessage)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
            PushSolidSunbeamButton(title: EmptySurfaceCopy.retryAction, action: retry)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, EmptySurfaceLayout.horizontalPadding)
    }
}
