//
//  FriendsView.swift
//  Push
//
//  The social layer: "who are my people and what are they up to?" Two modes —
//  Friends (direct friends with live context) and Groups (circles, reusing the
//  existing GroupsViewModel + GroupDetailView flow). Presented full-screen from
//  the map's nav; it owns no tab bar of its own.
//

import SwiftUI

struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: FriendsViewModel
    @StateObject private var groupsViewModel: GroupsViewModel
    @State private var mode: FriendsMode = .friends
    @State private var isAddFriendPresented = false
    @State private var isAddGroupPresented = false
    @State private var groupSearchText = ""

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: FriendsViewModel())
        _groupsViewModel = StateObject(wrappedValue: GroupsViewModel())
    }

    init(viewModel: FriendsViewModel, groupsViewModel: GroupsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _groupsViewModel = StateObject(wrappedValue: groupsViewModel)
    }

    var body: some View {
        if mode == .groups, let group = groupsViewModel.group(for: groupsViewModel.presentedGroupID) {
            GroupDetailView(
                group: group,
                members: groupsViewModel.members(for: group)
            ) {
                groupsViewModel.closeDetail()
            }
        } else {
            mainScreen
        }
    }

    private var mainScreen: some View {
        ZStack {
            FriendsBackground()

            VStack(spacing: FriendsLayout.screenStackSpacing) {
                FriendsHeader(
                    mode: mode,
                    onClose: { dismiss() }
                )
                FriendsModeSwitch(
                    mode: $mode,
                    friendsCount: viewModel.friendsCount,
                    groupsCount: groupsViewModel.groups.count
                )

                if mode == .friends {
                    FriendsSearchRow(
                        text: $viewModel.searchText,
                        placeholder: "Search friends",
                        addSymbolName: "person.badge.plus",
                        addAccessibilityLabel: "Add friend"
                    ) {
                        isAddFriendPresented = true
                    }
                    FriendsFilterChipRow(
                        selected: $viewModel.selectedFilter,
                        counts: viewModel.filterCounts
                    )
                } else {
                    FriendsSearchRow(
                        text: $groupSearchText,
                        placeholder: "Search groups",
                        addSymbolName: "person.3.fill",
                        addAccessibilityLabel: "Add group"
                    ) {
                        isAddGroupPresented = true
                    }
                }

                listContent
            }
            .padding(.horizontal, FriendsLayout.horizontalPadding)
            .padding(.top, FriendsLayout.topPadding)
        }
        .sheet(item: $viewModel.selectedFriend) { puck in
            FriendDetailSheet(puck: puck)
        }
        .sheet(isPresented: $isAddFriendPresented) {
            CreatePlaceholderView(
                title: "Add Friend",
                subtitle: "Invite someone to Push.",
                symbolName: "person.badge.plus"
            )
        }
        .sheet(isPresented: $isAddGroupPresented) {
            CreatePlaceholderView(
                title: "Add Group",
                subtitle: "Create a circle for the people you see together.",
                symbolName: "person.3.fill"
            )
        }
    }

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: FriendsLayout.listSpacing) {
                switch mode {
                case .friends:
                    friendsList
                case .groups:
                    groupsList
                }
            }
            .padding(.bottom, FriendsLayout.bottomPadding)
        }
    }

    @ViewBuilder
    private var friendsList: some View {
        let rows = viewModel.filteredRows
        if rows.isEmpty {
            FriendsEmptyState(mode: .friends, isSearching: !viewModel.searchText.isEmpty)
        } else {
            FriendsSectionHeader(title: sectionTitle, count: rows.count)
            ForEach(rows) { row in
                FriendRowCard(row: row) { viewModel.select(row) }
            }
        }
    }

    private var sectionTitle: String {
        viewModel.selectedFilter == .all ? "Friends" : viewModel.selectedFilter.title
    }

    @ViewBuilder
    private var groupsList: some View {
        let groups = filteredGroups
        if groups.isEmpty {
            FriendsEmptyState(mode: .groups, isSearching: !groupSearchText.isEmpty)
        } else {
            ForEach(groups) { group in
                FriendGroupCard(
                    group: group,
                    members: groupsViewModel.members(for: group)
                ) {
                    groupsViewModel.openDetail(for: group)
                }
            }
        }
    }

    private var filteredGroups: [PushGroupData] {
        let query = groupSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return groupsViewModel.groups }
        return groupsViewModel.groups.filter { group in
            group.name.localizedCaseInsensitiveContains(query)
        }
    }
}

// MARK: - Header

private struct FriendsHeader: View {
    let mode: FriendsMode
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: FriendsLayout.headerSubtitleSpacing) {
                Text("Friends")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)

                Text(mode.subtitle)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PushControlColors.inactiveForeground)
                    .animation(.easeInOut(duration: 0.2), value: mode)
            }

            Spacer(minLength: 0)

            FriendsCircleButton(systemImageName: "xmark", accessibilityLabel: "Close friends", action: onClose)
        }
    }
}

// MARK: - Mode Switch

private struct FriendsModeSwitch: View {
    @Binding var mode: FriendsMode
    let friendsCount: Int
    let groupsCount: Int
    @Namespace private var namespace

    private func count(for item: FriendsMode) -> Int {
        item == .friends ? friendsCount : groupsCount
    }

    var body: some View {
        HStack(spacing: FriendsLayout.switchItemSpacing) {
            ForEach(FriendsMode.allCases) { item in
                segment(item)
            }
        }
        .padding(FriendsLayout.switchPadding)
        .background(
            RoundedRectangle(cornerRadius: FriendsLayout.switchCornerRadius, style: .continuous)
                .fill(FriendsColor.switchTrack)
                .shadow(
                    color: FriendsColor.switchTrackShadow.opacity(FriendsColor.switchContainerShadowOpacity),
                    radius: FriendsLayout.switchContainerShadowRadius,
                    y: FriendsLayout.switchContainerShadowYOffset
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: FriendsLayout.switchCornerRadius, style: .continuous)
                .stroke(
                    FriendsColor.switchTrackHighlight.opacity(FriendsColor.switchContainerHighlightOpacity),
                    lineWidth: 0.8
                )
        }
        .overlay(alignment: .bottom) {
            RoundedRectangle(cornerRadius: FriendsLayout.switchCornerRadius, style: .continuous)
                .stroke(
                    FriendsColor.switchTrackShadow.opacity(FriendsColor.switchContainerInsetOpacity),
                    lineWidth: 1
                )
        }
    }

    private func segment(_ item: FriendsMode) -> some View {
        let isSelected = mode == item
        return Button {
            withAnimation(
                .spring(
                    response: FriendsLayout.switchAnimationResponse,
                    dampingFraction: FriendsLayout.switchAnimationDamping
                )
            ) {
                mode = item
            }
        } label: {
            HStack(spacing: FriendsLayout.switchCountSpacing) {
                Text(item.title)
                    .font(.subheadline.weight(isSelected ? .bold : .semibold))
                Text("\(count(for: item))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FriendsColor.switchCountText.opacity(isSelected ? 0.95 : 0.62))
                    .padding(.horizontal, FriendsLayout.switchCountHorizontalPadding)
                    .padding(.vertical, FriendsLayout.switchCountVerticalPadding)
                    .background(
                        Capsule().fill(
                            isSelected
                                ? FriendsColor.switchActiveCountFill
                                : FriendsColor.switchInactiveCountFill.opacity(0.58)
                        )
                    )
            }
            .foregroundStyle(isSelected ? FriendsColor.switchActiveText : FriendsColor.switchInactiveText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FriendsLayout.switchItemVerticalPadding)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: FriendsLayout.switchItemCornerRadius, style: .continuous)
                        .fill(FriendsColor.switchSelectedCream)
                        .shadow(
                            color: FriendsColor.switchSelectedShadow.opacity(FriendsColor.switchSelectedShadowOpacity),
                            radius: FriendsLayout.switchSelectedShadowRadius,
                            y: FriendsLayout.switchSelectedShadowYOffset
                        )
                        .matchedGeometryEffect(id: "friendsModeSelection", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue("\(count(for: item))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Search

private struct FriendsSearchRow: View {
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

// MARK: - Friend Row

private struct FriendRowCard: View {
    let row: FriendRowModel
    let action: () -> Void

    private var friend: FriendPuckData { row.friend }
    private var isHidden: Bool { friend.availability == .unavailable }

    var body: some View {
        Button(action: action) {
            HStack(spacing: FriendsLayout.rowSpacing) {
                avatar
                identity
                Spacer(minLength: 0)
                trailing
            }
            .padding(FriendsLayout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .friendsCard(cornerRadius: FriendsLayout.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(friend.name)
        .accessibilityValue(friend.venueStatusText)
    }

    private var avatar: some View {
        ProfilePhotoAvatar(
            imageAssetName: friend.profileImageAssetName,
            fallbackInitials: friend.avatarPlaceholder
        )
        .frame(width: FriendsLayout.rowAvatarSize, height: FriendsLayout.rowAvatarSize)
        .overlay {
            Circle()
                .stroke(
                    friend.availability.accentColor.opacity(FriendsColor.ringOpacity),
                    lineWidth: FriendsLayout.rowRingWidth
                )
        }
        .opacity(isHidden ? 0.72 : 1)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: FriendsLayout.rowTextSpacing) {
            Text(friend.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(1)

            HStack(spacing: FriendsLayout.rowSubtitleSpacing) {
                Image(systemName: friend.activitySymbolName)
                    .font(.system(size: FriendsLayout.rowSubtitleIconSize, weight: .semibold))
                    .foregroundStyle(friend.availability.accentColor)
                Text(friend.venueStatusText)
                    .font(.subheadline)
                    .foregroundStyle(PushControlColors.textSecondary)
                    .lineLimit(1)
            }

            if let groupLabel = row.groupLabel {
                groupTag(groupLabel)
            }
        }
    }

    private func groupTag(_ label: String) -> some View {
        HStack(spacing: FriendsLayout.rowGroupTagSpacing) {
            Image(systemName: "person.2.fill")
                .font(.system(size: FriendsLayout.rowGroupTagIconSize, weight: .semibold))
            Text(label)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(PushControlColors.textTertiary)
    }

    private var trailing: some View {
        VStack(alignment: .trailing, spacing: FriendsLayout.rowTrailingSpacing) {
            FriendsAvailabilityChip(availability: friend.availability)

            if !friend.lastUpdated.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(friend.availability.accentColor)
                        .frame(width: FriendsLayout.liveDotSize, height: FriendsLayout.liveDotSize)
                    Text(friend.lastUpdated)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PushControlColors.textTertiary)
                }
            }
        }
    }
}

struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        FriendsView()
    }
}
