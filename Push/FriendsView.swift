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
    @Environment(\.pushLayout) private var layout
    @StateObject private var viewModel: FriendsViewModel
    @StateObject private var groupsViewModel: GroupsViewModel
    @State private var mode: FriendsMode = .friends
    @State private var isAddFriendPresented = false
    @State private var isAddGroupPresented = false
    @State private var startPushContext: StartPushLaunchContext?
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
        content
            .fullScreenCover(item: $startPushContext) { context in
                StartPushFlowView(context: context)
            }
    }

    @ViewBuilder
    private var content: some View {
        if mode == .groups, let group = groupsViewModel.group(for: groupsViewModel.presentedGroupID) {
            GroupDetailView(
                group: group,
                members: groupsViewModel.members(for: group),
                onStartPush: { launchStartPush(.group(group.id)) }
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

            VStack(spacing: FriendsLayout.screenStackSpacing(layout)) {
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
            .padding(.horizontal, FriendsLayout.horizontalPadding(layout))
            .padding(.top, FriendsLayout.topPadding)

            if let selectedFriend = viewModel.selectedFriend {
                FriendDetailBottomSheet(
                    puck: selectedFriend,
                    onDismiss: dismissSelectedFriend,
                    onStartPush: launchStartPush
                )
            }
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
            .padding(.bottom, FriendsLayout.bottomPadding(layout))
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
                FriendRowCard(row: row) { selectFriend(row) }
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

    private func launchStartPush(_ context: StartPushLaunchContext) {
        dismissSelectedFriend()
        if groupsViewModel.presentedGroupID != nil {
            startPushContext = context
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + FriendsPresentationTiming.sheetDismissalDelay) {
            startPushContext = context
        }
    }

    private func selectFriend(_ row: FriendRowModel) {
        withAnimation(friendDetailSheetAnimation) {
            viewModel.select(row)
        }
    }

    private func dismissSelectedFriend() {
        withAnimation(friendDetailSheetAnimation) {
            viewModel.selectedFriend = nil
        }
    }

    private var friendDetailSheetAnimation: Animation {
        .interactiveSpring(
            response: FriendDetailBottomSheetLayout.animationResponse,
            dampingFraction: FriendDetailBottomSheetLayout.animationDamping,
            blendDuration: FriendDetailBottomSheetLayout.animationBlendDuration
        )
    }
}

private enum FriendsPresentationTiming {
    static let sheetDismissalDelay = 0.22
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

struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            FriendsView()
        }
    }
}
