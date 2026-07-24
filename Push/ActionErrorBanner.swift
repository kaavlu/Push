import SwiftUI

/// Non-blocking inline banner for failed mutations: message, Retry, dismiss.
struct ActionErrorBanner: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void
    @Environment(\.pushLayout) private var layout

    var body: some View {
        HStack(alignment: .center, spacing: ActionErrorBannerLayout.spacing) {
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PushControlColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Button("Retry", action: onRetry)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PushControlColors.textSecondary)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(ActionErrorBannerLayout.padding)
        .pushSolidCreamCard(cornerRadius: ActionErrorBannerLayout.cornerRadius(layout))
    }
}

private enum ActionErrorBannerLayout {
    static let spacing: CGFloat = 12
    static let padding: CGFloat = 14

    static func cornerRadius(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.cardCornerRadius
    }
}
