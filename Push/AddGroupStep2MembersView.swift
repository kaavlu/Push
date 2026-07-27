//
//  AddGroupStep2MembersView.swift
//  Push
//
//  Step 2 of Add Group: pick invitees. Reuses FriendRowCard with a circular
//  selection control (mirroring StartPushStep1View's RecipientSelectRow idiom)
//  instead of the default availability trailing.
//

import SwiftUI

struct AddGroupStep2MembersView: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var viewModel: AddGroupViewModel
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AddGroupStep2Layout.headerSpacing) {
                Text(selectionSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textSecondary)
                searchField
            }
            .padding(.horizontal, StartPushLayout.horizontalPadding(layout))
            .padding(.top, AddGroupStep2Layout.contentTopPadding)
            .padding(.bottom, AddGroupStep2Layout.searchBottomPadding)

            list
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StartPushPrimaryButton(
                title: "Review group",
                isEnabled: viewModel.canAdvanceStep2,
                action: onNext
            )
            .padding(.horizontal, StartPushLayout.horizontalPadding(layout))
            .padding(.bottom, StartPushLayout.bottomPadding(layout))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var selectionSummary: String {
        let count = viewModel.selectedFriendIDs.count
        return "\(count) selected"
    }

    private var searchField: some View {
        HStack(spacing: FriendsLayout.searchSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: FriendsLayout.searchIconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textTertiary)
            TextField("Search friends", text: $viewModel.memberSearchText)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !viewModel.memberSearchText.isEmpty {
                Button { viewModel.memberSearchText = "" } label: {
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

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: FriendsLayout.listSpacing) {
                if viewModel.memberRows.isEmpty {
                    FriendsEmptyState(mode: .friends, isSearching: !viewModel.memberSearchText.isEmpty)
                } else {
                    ForEach(viewModel.memberRows) { item in
                        memberRow(item)
                    }
                }
            }
            .padding(.horizontal, StartPushLayout.horizontalPadding(layout))
            .padding(.bottom, AddGroupStep2Layout.listBottomPadding)
        }
    }

    private func memberRow(_ item: AddGroupMemberRow) -> some View {
        let isSelected = viewModel.selectedFriendIDs.contains(item.id)
        return FriendRowCard(
            row: item.friendRow,
            showsGroupLabel: false,
            usesAvailabilityAppearance: false,
            customTrailing: AnyView(selectionIndicator(isSelected: isSelected)),
            action: { viewModel.toggleSelection(item.id) }
        )
        // Layered on top of the card's own cream fill, not replacing it, per
        // the "don't fight the existing card background" call.
        .background {
            RoundedRectangle(cornerRadius: FriendsLayout.cardCornerRadius, style: .continuous)
                .fill(PushControlColors.activeFill.opacity(isSelected ? AddGroupStep2Color.selectedTintOpacity : 0))
        }
        .overlay {
            RoundedRectangle(cornerRadius: FriendsLayout.cardCornerRadius, style: .continuous)
                .stroke(
                    PushControlColors.activeFill.opacity(isSelected ? AddGroupStep2Color.selectedStrokeOpacity : 0),
                    lineWidth: AddGroupStep2Layout.selectedStrokeWidth
                )
        }
        .animation(.easeInOut(duration: 0.16), value: isSelected)
    }

    @ViewBuilder
    private func selectionIndicator(isSelected: Bool) -> some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: StartPushLayout.selectionCircleSize, weight: .bold))
                .foregroundStyle(PushControlColors.activeForeground)
        } else {
            Image(systemName: "circle")
                .font(.system(size: StartPushLayout.selectionCircleSize, weight: .regular))
                .foregroundStyle(PushControlColors.textTertiary)
        }
    }
}

private enum AddGroupStep2Layout {
    static let headerSpacing: CGFloat = 12
    static let contentTopPadding: CGFloat = 4
    static let searchBottomPadding: CGFloat = 10
    static let listBottomPadding: CGFloat = 24
    static let selectedStrokeWidth: CGFloat = 1.5
}

private enum AddGroupStep2Color {
    static let selectedTintOpacity = 0.14
    static let selectedStrokeOpacity = 0.5
}
