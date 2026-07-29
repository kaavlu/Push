//
//  CreatePostSelectFriendsView.swift
//  Push
//
//  Scratch-only friend multi-select — Start Push step 1 visual language
//  (search, cream selectable rows, selected chips, solid Next). Friends only.
//

import SwiftUI

struct CreatePostSelectFriendsView: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var viewModel: CreatePostViewModel
    let onNext: () -> Void

    var body: some View {
        Group {
            if viewModel.availableFriends.isEmpty {
                emptyState
            } else {
                friendPicker
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 0) {
            StartPushHeader(
                title: CreatePostCopy.selectFriendsTitle,
                subtitle: CreatePostCopy.selectFriendsSubtitle
            )
            .padding(.horizontal, CreatePostLayout.horizontalPadding(layout))
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
            EmptySurfaceView(
                title: CreatePostCopy.selectFriendsEmptyTitle,
                message: CreatePostCopy.selectFriendsEmptyMessage,
                systemImage: "person.badge.plus"
            )
            Spacer(minLength: 0)

            PushSolidSunbeamButton(
                title: viewModel.friendPickerPrimaryTitle,
                isEnabled: viewModel.canContinueFromFriends,
                action: onNext
            )
            .padding(.horizontal, CreatePostLayout.horizontalPadding(layout))
            .padding(.bottom, CreatePostLayout.bottomPadding(layout))
        }
    }

    // MARK: - Picker

    private var friendPicker: some View {
        ScrollView {
            VStack(spacing: StartPushLayout.sectionSpacing(layout)) {
                StartPushHeader(
                    title: CreatePostCopy.selectFriendsTitle,
                    subtitle: CreatePostCopy.selectFriendsSubtitle
                )
                StartPushSearchBar(
                    text: $viewModel.friendSearchText,
                    placeholder: CreatePostCopy.selectFriendsSearchPlaceholder
                )
                friendSection
            }
            .padding(.horizontal, CreatePostLayout.horizontalPadding(layout))
            .padding(.bottom, CreatePostLayout.contentTopSpacing)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
                .padding(.horizontal, CreatePostLayout.horizontalPadding(layout))
                .padding(.bottom, CreatePostLayout.bottomPadding(layout))
                .background(bottomBarBackground)
        }
    }

    private var bottomBarBackground: some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.92)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var friendSection: some View {
        VStack(alignment: .leading, spacing: StartPushLayout.sectionLabelSpacing) {
            Text(CreatePostCopy.selectFriendsSection)
                .pushSectionLabelStyle()
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.filteredFriends.isEmpty {
                Text(EmptySurfaceCopy.searchNoMatchTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, StartPushLayout.rowVerticalPadding)
            } else {
                VStack(spacing: StartPushLayout.rowSpacing) {
                    ForEach(viewModel.filteredFriends) { friend in
                        CreatePostFriendSelectRow(
                            item: friend,
                            isSelected: viewModel.isFriendSelected(friend.id),
                            action: { viewModel.toggleFriend(friend.id) }
                        )
                    }
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if !viewModel.selectedFriends.isEmpty {
                selectedChips
            }
            PushSolidSunbeamButton(
                title: viewModel.friendPickerPrimaryTitle,
                isEnabled: viewModel.canContinueFromFriends,
                action: onNext
            )
        }
    }

    private var selectedChips: some View {
        let all = viewModel.selectedFriends
        let hasOverflow = all.count > StartPushLayout.maxVisibleChips
        let visibleCount = hasOverflow
            ? StartPushLayout.maxVisibleChipsWithOverflow
            : all.count
        let visible = Array(all.prefix(visibleCount))
        let overflow = all.count - visible.count

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visible) { friend in
                    CreatePostSelectedFriendChip(item: friend) {
                        viewModel.toggleFriend(friend.id)
                    }
                }
                if overflow > 0 {
                    CreatePostOverflowChip(count: overflow)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Start Push–style selection chrome (feature-local, same metrics)

private struct CreatePostSelectableCardSurface: View {
    let cornerRadius: CGFloat
    let isSelected: Bool

    var body: some View {
        Color.clear
            .pushSolidCreamCard(cornerRadius: cornerRadius)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            PushControlColors.activeFill.opacity(StartPushColor.selectedTintOpacity)
                        )
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            PushControlColors.activeFill.opacity(StartPushColor.selectedStrokeOpacity),
                            lineWidth: StartPushColor.selectedStrokeWidth
                        )
                }
            }
    }
}

private struct CreatePostFriendSelectRow: View {
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
                    .lineLimit(1)
                Spacer(minLength: 0)
                selectionIndicator
            }
            .padding(.horizontal, StartPushLayout.rowHorizontalPadding)
            .padding(.vertical, StartPushLayout.rowVerticalPadding)
            .background(
                CreatePostSelectableCardSurface(
                    cornerRadius: StartPushLayout.rowCornerRadius,
                    isSelected: isSelected
                )
            )
        }
        .buttonStyle(.plain)
        .animation(PushMotion.selectionSnappy, value: isSelected)
        .accessibilityLabel(item.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(.isButton)
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

private struct CreatePostSelectedFriendChip: View {
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
            .accessibilityLabel("Remove \(item.name)")
        }
        .padding(.horizontal, StartPushLayout.chipHorizontalPadding)
        .padding(.vertical, StartPushLayout.chipVerticalPadding)
        .background(Capsule().fill(PushControlColors.activeFill))
    }
}

private struct CreatePostOverflowChip: View {
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

#if DEBUG
struct CreatePostSelectFriendsView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            ZStack {
                PushModalBackground()
                CreatePostSelectFriendsView(
                    viewModel: CreatePostViewModel(timing: .immediate),
                    onNext: {}
                )
            }
        }
    }
}
#endif
