//
//  FriendsSearchRow.swift
//  Push
//
//  Search field + add button used above both the Friends and Groups lists,
//  plus the small toast the Friends screen surfaces for Directions/Remove
//  feedback (split out of FriendsView.swift to keep it under the file
//  length guideline).
//

import SwiftUI

struct FriendsSearchRow: View {
    @Binding var text: String
    let placeholder: String
    let addSymbolName: String
    let addAccessibilityLabel: String
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: FriendsLayout.searchRowSpacing) {
            FriendsSearchField(text: $text, placeholder: placeholder)
            FriendsCircleButton(
                systemImageName: addSymbolName,
                accessibilityLabel: addAccessibilityLabel,
                action: onAdd
            )
        }
    }
}

private struct FriendsSearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: FriendsLayout.searchSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: FriendsLayout.searchIconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textTertiary)

            TextField(placeholder, text: $text)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: FriendsLayout.searchIconSize, weight: .semibold))
                        .foregroundStyle(PushControlColors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, FriendsLayout.searchHorizontalPadding)
        .padding(.vertical, FriendsLayout.searchVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: FriendsLayout.searchCornerRadius, style: .continuous)
                .fill(FriendsColor.cardCream.opacity(FriendsColor.cardCreamOpacity))
        )
        .overlay {
            RoundedRectangle(cornerRadius: FriendsLayout.searchCornerRadius, style: .continuous)
                .stroke(
                    PushColorPalette.Accent.walnut.opacity(FriendsColor.chipStrokeWalnutOpacity),
                    lineWidth: FriendsColor.cardStrokeWidth
                )
        }
    }
}

/// Lightweight top-of-screen confirmation, mirroring `FriendDetailSheet`'s
/// inline toast for Directions/Ask-to-join feedback.
struct FriendsToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PushControlColors.activeForeground)
            .padding(.horizontal, FriendDetailSheetLayout.toastHorizontalPadding)
            .padding(.vertical, FriendDetailSheetLayout.toastVerticalPadding)
            .pushGlassBackground(cornerRadius: FriendDetailSheetLayout.toastCornerRadius)
    }
}
