//
//  FriendsView.swift
//  Push
//
//  The social layer: "who are my people and what are they up to?" Two modes —
//  Friends (direct friends with live context) and Groups (circles, reusing the
//  existing GroupsViewModel + GroupDetailView flow). Embedded under ContentView's
//  bottom nav; leave via the shared tab bar (no page-level close control).
//

import SwiftUI

struct FriendsView: View {
    @Environment(\.pushLayout) private var layout
    private let onLocateFriend: (Person.ID) -> Bool
    /// When set (e.g. from map Who’s here), expand that friend row after present.
    @Binding private var focusFriendID: String?
    @StateObject private var viewModel: FriendsViewModel
    @StateObject private var groupsViewModel: GroupsViewModel
    @State private var mode: FriendsMode = .friends
    @State private var isAddFriendPresented = false
    @State private var isAddGroupPresented = false
    @State private var startPushContext: StartPushLaunchContext?
    @State private var groupSearchText = ""
    @State private var toastMessage: String?

    @MainActor
    init(
        onLocateFriend: @escaping (Person.ID) -> Bool = { _ in false },
        focusFriendID: Binding<String?> = .constant(nil)
    ) {
        self.onLocateFriend = onLocateFriend
        _focusFriendID = focusFriendID
        _viewModel = StateObject(wrappedValue: FriendsViewModel())
        _groupsViewModel = StateObject(wrappedValue: GroupsViewModel())
    }

    init(
        viewModel: FriendsViewModel,
        groupsViewModel: GroupsViewModel,
        onLocateFriend: @escaping (Person.ID) -> Bool = { _ in false },
        focusFriendID: Binding<String?> = .constant(nil)
    ) {
        self.onLocateFriend = onLocateFriend
        _focusFriendID = focusFriendID
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
            .onAppear(perform: consumeFocusFriendIfNeeded)
            .onChange(of: focusFriendID) { _ in
                consumeFocusFriendIfNeeded()
            }
    }

    private func consumeFocusFriendIfNeeded() {
        guard let id = focusFriendID else { return }
        mode = .friends
        viewModel.expandFriend(id: id)
        focusFriendID = nil
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
                FriendsHeader(mode: mode)
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
                .padding(.bottom, FriendsLayout.contentBottomClearance(layout))
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
                // Clear the floating bottom nav that stays on this page.
                .padding(.bottom, FriendsLayout.contentBottomClearance(layout))
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
                    onAvatarTap: { locateOnMap(row) },
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

    private func locateOnMap(_ row: FriendRowModel) {
        // ContentView switches to Map on success; no page-level close control.
        _ = onLocateFriend(row.friend.id)
    }

    private func triggerToast(_ message: String) {
        withAnimation(PushMotion.hangoutReveal) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(PushMotion.hangoutReveal) {
                toastMessage = nil
            }
        }
    }
}

// MARK: - Header

private struct FriendsHeader: View {
    let mode: FriendsMode

    var body: some View {
        // Title only — leave via the shared bottom nav (no close control).
        PushCreamPageHeader(title: "Friends", subtitle: mode.subtitle)
            .animation(PushMotion.contentCrossfade, value: mode)
    }
}

// MARK: - Mode Switch (DS-035)

private struct FriendsModeSwitch: View {
    @Binding var mode: FriendsMode
    let friendsCount: Int
    let groupsCount: Int

    private var selectedID: Binding<String> {
        Binding(
            get: { mode.rawValue },
            set: { mode = FriendsMode(rawValue: $0) ?? .friends }
        )
    }

    private var items: [PushIvorySegmentedItem] {
        FriendsMode.allCases.map { item in
            PushIvorySegmentedItem(
                id: item.rawValue,
                title: item.title,
                count: item == .friends ? friendsCount : groupsCount
            )
        }
    }

    var body: some View {
        PushIvorySegmentedControl(items: items, selectedID: selectedID)
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
