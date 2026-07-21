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
    @State private var toastMessage: String?

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
        mainScreen
            // Same system slide-up / slide-down as Profile (fullScreenCover).
            .fullScreenCover(item: presentedGroupBinding) { group in
                GroupDetailHost(
                    viewModel: groupsViewModel,
                    group: group,
                    onStartPush: { launchStartPush(.group(group.id)) }
                )
            }
            .fullScreenCover(item: $startPushContext) { context in
                StartPushFlowView(context: context)
            }
            .onChange(of: mode) { newMode in
                // Detail only exists in Groups mode; leaving the tab dismisses it.
                if newMode != .groups {
                    groupsViewModel.closeDetail()
                }
            }
    }

    /// Drives profile-style cover presentation for group detail.
    private var presentedGroupBinding: Binding<PushGroupData?> {
        Binding(
            get: {
                guard mode == .groups else { return nil }
                return groupsViewModel.group(for: groupsViewModel.presentedGroupID)
            },
            set: { newValue in
                if newValue == nil {
                    groupsViewModel.closeDetail()
                }
            }
        )
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
                    if viewModel.showsFilterChips {
                        FriendsFilterChipRow(
                            selected: $viewModel.selectedFilter,
                            counts: viewModel.filterCounts
                        )
                    }
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

            if let toastMessage {
                FriendsToast(message: toastMessage)
                    .padding(.top, FriendsLayout.topPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let actionError = viewModel.actionError {
                ActionErrorBanner(
                    message: actionError.message,
                    onRetry: { Task { await viewModel.retryLastAction() } },
                    onDismiss: { viewModel.dismissActionError() }
                )
                .padding(.horizontal, FriendsLayout.horizontalPadding(layout))
                .padding(.bottom, FriendsLayout.bottomPadding(layout))
            }
        }
        .fullScreenCover(isPresented: $isAddFriendPresented) {
            AddFriendsView()
        }
        .fullScreenCover(isPresented: $isAddGroupPresented) {
            AddGroupFlowView { groupID, image in
                handleGroupCreated(groupID: groupID, image: image)
            }
        }
        .onChange(of: mode) { _ in viewModel.collapse() }
    }

    private var listContent: some View {
        ScrollViewReader { proxy in
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
            .refreshable {
                await viewModel.refresh()
                await groupsViewModel.load()
            }
            .onChange(of: viewModel.expandedFriendID) { expandedID in
                guard let expandedID else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(expandedID, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private var friendsList: some View {
        switch viewModel.surfacePhase {
        case .loading:
            EmptySurfaceStateView.loading(message: EmptySurfaceCopy.friendsLoading)
        case .failed:
            EmptySurfaceStateView.failed(surface: "friends") {
                Task { await viewModel.load() }
            }
        case .empty:
            FriendsEmptyState(
                mode: .friends,
                isSearching: false,
                onAddFriends: { isAddFriendPresented = true }
            )
        case .content:
            friendsContentList
        case .deferred:
            EmptyView()
        }
    }

    @ViewBuilder
    private var friendsContentList: some View {
        let rows = viewModel.filteredRows
        if rows.isEmpty {
            FriendsEmptyState(mode: .friends, isSearching: !viewModel.searchText.isEmpty)
        } else {
            FriendsSectionHeader(title: sectionTitle, count: rows.count)
            ForEach(rows) { row in
                ExpandableFriendRow(
                    row: row,
                    isExpanded: viewModel.expandedFriendID == row.id,
                    isRemoving: viewModel.removingFriendIDs.contains(row.id),
                    isBlocking: viewModel.blockingFriendIDs.contains(row.id),
                    onToggle: { selectFriend(row) },
                    onDirections: { triggerToast("Opening in Maps…") },
                    onStartPush: { startPush(for: row) },
                    onRemove: { Task { await viewModel.removeFriend(row) } },
                    onBlock: { Task { await viewModel.blockFriend(row) } }
                )
                .id(row.id)
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
        startPushContext = context
    }

    /// Registering the picked photo must happen synchronously, before the
    /// reload — `GroupDetailView` reads it via `sessionImage(for:)` as soon
    /// as `openDetail` presents the freshly-created group.
    private func handleGroupCreated(groupID: FriendGroup.ID, image: UIImage?) {
        groupsViewModel.registerSessionImage(image, forGroupID: groupID)
        mode = .groups
        Task {
            await groupsViewModel.load()
            if let group = groupsViewModel.group(for: groupID) {
                groupsViewModel.openDetail(for: group)
            }
        }
    }

    private func selectFriend(_ row: FriendRowModel) {
        withAnimation { viewModel.toggleExpanded(row) }
    }

    private func startPush(for row: FriendRowModel) {
        viewModel.collapse()
        launchStartPush(.friends([row.friend.id], locationHint: row.friend.placeName))
    }

    private func triggerToast(_ message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                toastMessage = nil
            }
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

#if DEBUG
struct FriendsView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            FriendsView()
        }
    }
}
#endif
