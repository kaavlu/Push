//
//  ProfileAccountActions.swift
//  Push
//
//  Session lifecycle actions on Profile — same glass-card language as
//  Settings / Legal, using brand destructive color instead of system red.
//

import SwiftUI

/// Sign Out / Delete Account grouped like other Profile sections.
struct ProfileAccountActionsCard: View {
    let showSignOut: Bool
    let isSigningOut: Bool
    let onSignOut: () -> Void
    let showDeleteAccount: Bool
    let isDeletingAccount: Bool
    let onDeleteAccount: () -> Void

    private var isBusy: Bool { isSigningOut || isDeletingAccount }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ProfileLayout.rowSpacing) {
                SectionTitle("Account")
                if showSignOut {
                    ProfileSessionActionRow(
                        symbolName: "rectangle.portrait.and.arrow.right",
                        title: "Sign Out",
                        subtitle: "End your session on this device",
                        style: .standard,
                        isBusy: isSigningOut,
                        isDisabled: isBusy,
                        action: onSignOut
                    )
                }
                if showDeleteAccount {
                    ProfileSessionActionRow(
                        symbolName: "trash",
                        title: "Delete Account",
                        subtitle: "Permanently remove your profile and data",
                        style: .destructive,
                        isBusy: isDeletingAccount,
                        isDisabled: isBusy,
                        action: onDeleteAccount
                    )
                }
            }
        }
    }
}

private enum ProfileSessionActionStyle {
    case standard
    case destructive

    var titleColor: Color {
        switch self {
        case .standard: return PushControlColors.textEspresso
        case .destructive: return PushControlColors.destructive
        }
    }

    var iconColor: Color {
        switch self {
        case .standard: return PushControlColors.activeForeground
        case .destructive: return PushControlColors.destructive
        }
    }
}

private struct ProfileSessionActionRow: View {
    let symbolName: String
    let title: String
    let subtitle: String
    let style: ProfileSessionActionStyle
    let isBusy: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ProfileLayout.rowIconSpacing) {
                Image(systemName: symbolName)
                    .font(.system(size: ProfileLayout.statusIconSize, weight: .bold))
                    .foregroundStyle(style.iconColor)
                    .frame(
                        width: ProfileLayout.statusIconFrame,
                        height: ProfileLayout.statusIconFrame
                    )
                    .background(
                        Circle().fill(.white.opacity(ProfileColor.iconFillOpacity))
                    )

                VStack(alignment: .leading, spacing: ProfileLayout.rowTextSpacing) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(style.titleColor)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PushControlColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if isBusy {
                    ProgressView()
                        .tint(style.iconColor)
                }
            }
            .padding(ProfileLayout.rowPadding)
            .background(
                RoundedRectangle(cornerRadius: ProfileLayout.rowCornerRadius, style: .continuous)
                    .fill(.white.opacity(ProfileColor.rowFillOpacity))
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}
