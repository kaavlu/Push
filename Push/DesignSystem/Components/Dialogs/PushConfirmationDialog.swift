//
//  PushConfirmationDialog.swift
//  Push
//
//  DS-090 — centered cream confirmation dialog for destructive (and future
//  standard) confirms. Replaces system confirmationDialog for those flows.
//

import SwiftUI

// MARK: - Models

/// Confirm button role. Destructive is the primary ship path; primary is reserved.
enum PushConfirmationRole: Equatable {
    case destructive
    case primary
}

/// Presentation content for a confirmation dialog.
struct PushConfirmationConfig: Equatable {
    var title: String
    var message: String? = nil
    var confirmTitle: String
    var confirmRole: PushConfirmationRole = .destructive
    var cancelTitle: String = "Cancel"
}

// MARK: - Dialog content

/// Pure confirmation card: title, optional message, confirm + cancel.
struct PushConfirmationDialog: View {
    @Environment(\.pushLayout) private var layout

    let config: PushConfirmationConfig
    var isConfirmLoading: Bool = false
    var isConfirmDisabled: Bool = false
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var confirmEnabled: Bool {
        !isConfirmDisabled && !isConfirmLoading
    }

    var body: some View {
        VStack(spacing: PushConfirmationLayout.contentButtonsSpacing) {
            VStack(spacing: PushConfirmationLayout.titleMessageSpacing) {
                Text(config.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if let message = config.message, !message.isEmpty {
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PushControlColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: PushConfirmationLayout.buttonSpacing) {
                confirmButton
                cancelButton
            }
        }
        .padding(PushConfirmationLayout.cardPadding)
        .frame(maxWidth: PushConfirmationLayout.maxCardWidth)
        .pushSolidCreamCard(cornerRadius: PushRadiusTokens.card(layout))
        .accessibilityElement(children: .contain)
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            ZStack {
                Text(config.confirmTitle)
                    .opacity(isConfirmLoading ? 0 : 1)
                if isConfirmLoading {
                    ProgressView()
                        .tint(confirmForeground)
                }
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(confirmForeground)
            .frame(maxWidth: .infinity)
            .frame(height: PushConfirmationLayout.buttonHeight)
            .background(confirmBackground, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!confirmEnabled)
        .opacity(confirmEnabled ? 1 : PushOpacityTokens.disabledControl)
        .accessibilityLabel(config.confirmTitle)
        .accessibilityHint(confirmAccessibilityHint)
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text(config.cancelTitle)
                .font(.body.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: PushConfirmationLayout.cancelHitHeight)
        }
        .buttonStyle(.plain)
        .disabled(isConfirmLoading)
        .accessibilityLabel(config.cancelTitle)
    }

    private var confirmBackground: Color {
        switch config.confirmRole {
        case .destructive:
            return PushControlColors.destructive
        case .primary:
            return PushControlColors.activeFill
        }
    }

    private var confirmForeground: Color {
        switch config.confirmRole {
        case .destructive:
            return Color.white
        case .primary:
            return PushControlColors.activeForeground
        }
    }

    private var confirmAccessibilityHint: String {
        switch config.confirmRole {
        case .destructive:
            return "Destructive action. Double-tap to confirm."
        case .primary:
            return "Double-tap to confirm."
        }
    }
}

// MARK: - Presenter

/// Full-screen scrim + centered card. Scrim tap cancels.
struct PushConfirmationPresenter: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let config: PushConfirmationConfig
    var isConfirmLoading: Bool = false
    var isConfirmDisabled: Bool = false
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .opacity(PushOpacityTokens.dialogScrim)
                .ignoresSafeArea()
                .onTapGesture {
                    guard !isConfirmLoading else { return }
                    onCancel()
                }
                .accessibilityHidden(true)

            PushConfirmationDialog(
                config: config,
                isConfirmLoading: isConfirmLoading,
                isConfirmDisabled: isConfirmDisabled,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
            .padding(.horizontal, PushConfirmationLayout.horizontalInset)
            .transition(cardTransition)
        }
    }

    private var cardTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .scale(scale: PushConfirmationLayout.presentScale))
    }
}

// MARK: - Layout

enum PushConfirmationLayout {
    static let horizontalInset: CGFloat = 28
    static let maxCardWidth: CGFloat = 340
    static let cardPadding: CGFloat = 22
    static let titleMessageSpacing: CGFloat = 8
    static let contentButtonsSpacing: CGFloat = 20
    static let buttonSpacing: CGFloat = 10
    static let buttonHeight: CGFloat = 50
    static let cancelHitHeight: CGFloat = 44
    static let presentScale: CGFloat = 0.96
}

// MARK: - Previews

#if DEBUG
struct PushConfirmationDialog_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            ZStack {
                PushIvoryPageBackground()
                PushConfirmationPresenter(
                    config: PushConfirmationConfig(
                        title: "Delete Account?",
                        message: "This permanently deletes your account and cannot be undone.",
                        confirmTitle: "Delete Account",
                        confirmRole: .destructive,
                        cancelTitle: "Cancel"
                    ),
                    onConfirm: {},
                    onCancel: {}
                )
            }

            ZStack {
                PushModalBackground()
                PushConfirmationPresenter(
                    config: PushConfirmationConfig(
                        title: "Sign out?",
                        confirmTitle: "Sign Out"
                    ),
                    isConfirmLoading: true,
                    onConfirm: {},
                    onCancel: {}
                )
            }
        }
    }
}
#endif
