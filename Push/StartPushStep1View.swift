//
//  StartPushStep1View.swift
//  Push
//
//  Created by Manav Khanvilkar on 7/1/26.
//

import SwiftUI

struct StartPushStep1View: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var viewModel: StartPushViewModel
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: StartPushLayout.sectionSpacing(layout)) {
                StartPushHeader(
                    title: "Who's this for?",
                    subtitle: "Choose groups or friends to send this push to."
                )
                StartPushSearchBar(text: $viewModel.searchText, placeholder: "Search people or groups")
                groupSection
                friendSection
            }
            .padding(.horizontal, StartPushLayout.horizontalPadding(layout))
            .padding(.bottom, StartPushLayout.contentTopSpacing)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
                .padding(.horizontal, StartPushLayout.horizontalPadding(layout))
                .padding(.bottom, StartPushLayout.bottomPadding(layout))
                .background(bottomBarBackground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bottomBarBackground: some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.92)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var groupSection: some View {
        VStack(alignment: .leading, spacing: StartPushLayout.sectionLabelSpacing) {
            StartPushSectionLabel(title: "Groups")
            LazyVGrid(columns: groupColumns, spacing: StartPushLayout.groupCardSpacing(layout)) {
                ForEach(viewModel.filteredGroups) { group in
                    GroupSelectCard(
                        item: group,
                        isSelected: viewModel.isSelected(group.id),
                        action: { viewModel.toggleRecipient(group.id) }
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var groupColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: StartPushLayout.groupCardMinWidth(layout)),
                spacing: StartPushLayout.groupCardSpacing(layout)
            )
        ]
    }

    private var friendSection: some View {
        VStack(alignment: .leading, spacing: StartPushLayout.sectionLabelSpacing) {
            StartPushSectionLabel(title: "Friends")
            VStack(spacing: StartPushLayout.rowSpacing) {
                ForEach(viewModel.filteredFriends) { friend in
                    FriendSelectRow(
                        item: friend,
                        isSelected: viewModel.isSelected(friend.id),
                        action: { viewModel.toggleRecipient(friend.id) }
                    )
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if !viewModel.selectedRecipients.isEmpty {
                selectedChips
            }
            StartPushPrimaryButton(title: "Next", isEnabled: viewModel.canAdvanceStep1, action: onNext)
        }
    }

    private var selectedChips: some View {
        let all = viewModel.selectedRecipients
        let hasOverflow = all.count > StartPushLayout.maxVisibleChips
        let visibleCount = hasOverflow ? StartPushLayout.maxVisibleChipsWithOverflow : all.count
        let visible = Array(all.prefix(visibleCount))
        let overflow = all.count - visible.count

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visible) { recipient in
                    SelectedRecipientChip(item: recipient) {
                        viewModel.toggleRecipient(recipient.id)
                    }
                }
                if overflow > 0 {
                    OverflowChip(count: overflow)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

private struct GroupSelectCard: View {
    @Environment(\.pushLayout) private var layout
    let item: PushRecipientItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    RecipientAvatarView(
                        imageAssetName: item.imageAssetName,
                        initials: item.initials,
                        size: StartPushLayout.groupAvatarSize(layout)
                    )
                    if isSelected { checkmark }
                }
                Text(item.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? PushControlColors.activeForeground : PushControlColors.textEspresso)
                    .lineLimit(1)
                if let count = item.memberCount {
                    HStack(spacing: 3) {
                        Image(systemName: "person.fill")
                            .font(.system(size: StartPushLayout.memberCountIconSize))
                        Text("\(count)")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(PushControlColors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: StartPushLayout.groupCardHeight(layout))
            .background(
                RoundedRectangle(cornerRadius: StartPushLayout.cardCornerRadius(layout), style: .continuous)
                    .fill(isSelected ? PushControlColors.activeFill : .white.opacity(StartPushColor.rowFillOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: StartPushLayout.cardCornerRadius(layout), style: .continuous)
                    .stroke(
                        isSelected ? PushColorPalette.Accent.walnut.opacity(StartPushColor.selectedStrokeOpacity) : .clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isSelected)
        .accessibilityLabel(item.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var checkmark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: StartPushLayout.groupCheckmarkSize, weight: .bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .background(Circle().fill(.white))
            .offset(x: StartPushLayout.groupCardCheckOffset, y: StartPushLayout.groupCardCheckOffset)
    }
}

private struct FriendSelectRow: View {
    let item: PushRecipientItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RecipientAvatarView(
                    imageAssetName: item.imageAssetName,
                    initials: item.initials,
                    size: StartPushLayout.friendRowAvatarSize
                )
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                Spacer(minLength: 0)
                selectionIndicator
            }
            .padding(.horizontal, StartPushLayout.rowHorizontalPadding)
            .padding(.vertical, StartPushLayout.rowVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: StartPushLayout.rowCornerRadius, style: .continuous)
                    .fill(isSelected ? PushControlColors.activeFill : .white.opacity(StartPushColor.rowFillOpacity))
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isSelected)
        .accessibilityLabel(item.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    @ViewBuilder
    private var selectionIndicator: some View {
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

private struct SelectedRecipientChip: View {
    let item: PushRecipientItem
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            RecipientAvatarView(
                imageAssetName: item.imageAssetName,
                initials: item.initials,
                size: StartPushLayout.chipAvatarSize
            )
            Text(item.name)
                .font(.caption.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)
            Button(action: removeAction) {
                Image(systemName: "xmark")
                    .font(.system(size: StartPushLayout.chipIconSize, weight: .bold))
                    .foregroundStyle(PushControlColors.activeForeground.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, StartPushLayout.chipHorizontalPadding)
        .padding(.vertical, StartPushLayout.chipVerticalPadding)
        .background(Capsule().fill(PushControlColors.activeFill))
    }
}

private struct OverflowChip: View {
    let count: Int

    var body: some View {
        Text("+\(count) more")
            .font(.caption.weight(.bold))
            .foregroundStyle(PushControlColors.activeForeground.opacity(0.7))
            .padding(.horizontal, StartPushLayout.chipHorizontalPadding)
            .padding(.vertical, StartPushLayout.chipVerticalPadding)
            .background(Capsule().fill(.white.opacity(StartPushColor.rowFillOpacity)))
    }
}
