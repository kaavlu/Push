//
//  BlockedUsersView.swift
//  Push
//
//  Cream full-screen list of people the user has blocked. Unblock confirms
//  that friendship is not restored automatically.
//

import SwiftUI

struct BlockedUsersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout
    @StateObject private var viewModel: BlockedUsersViewModel
    @State private var personPendingUnblock: BlockedPerson?

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: BlockedUsersViewModel())
    }

    @MainActor
    init(viewModel: BlockedUsersViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            FriendsBackground()

            VStack(spacing: FriendsLayout.screenStackSpacing(layout)) {
                header
                content
            }
            .padding(.horizontal, FriendsLayout.horizontalPadding(layout))
            .padding(.top, FriendsLayout.topPadding)
        }
        .toolbar(.hidden, for: .navigationBar)
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
        .task {
            await viewModel.load()
        }
        .confirmationDialog(
            unblockConfirmTitle,
            isPresented: Binding(
                get: { personPendingUnblock != nil },
                set: { if !$0 { personPendingUnblock = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let person = personPendingUnblock {
                Button("Unblock", role: .destructive) {
                    personPendingUnblock = nil
                    Task { await viewModel.unblock(person) }
                }
            }
            Button("Cancel", role: .cancel) {
                personPendingUnblock = nil
            }
        } message: {
            Text(BlockedUsersCopy.unblockMessage)
        }
    }

    private var unblockConfirmTitle: String {
        if let person = personPendingUnblock {
            return "Unblock \(BlockedUsersCopy.displayName(person))?"
        }
        return "Unblock?"
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: FriendsLayout.headerSubtitleSpacing) {
                Text(BlockedUsersCopy.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                Text(BlockedUsersCopy.subtitle)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PushControlColors.inactiveForeground)
            }
            Spacer(minLength: 0)
            FriendsCircleButton(
                systemImageName: "xmark",
                accessibilityLabel: "Close blocked list",
                action: { dismiss() }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            EmptySurfaceStateView.loading(message: EmptySurfaceCopy.blockedLoading)
        case .failed:
            EmptySurfaceStateView.failed(surface: EmptySurfaceCopy.blockedSurfaceName) {
                Task { await viewModel.load() }
            }
        case .loaded(let people):
            if people.isEmpty {
                EmptySurfaceView(
                    title: EmptySurfaceCopy.blockedEmptyTitle,
                    systemImage: "hand.raised",
                    expandsVertically: true
                )
            } else {
                peopleList(people)
            }
        }
    }

    private func peopleList(_ people: [BlockedPerson]) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: FriendsLayout.listSpacing) {
                ForEach(people) { person in
                    PushPersonRow(
                        row: person.personRowModel,
                        showsGroupLabel: false,
                        showsStatusDetail: true,
                        usesAvailabilityAppearance: false,
                        customTrailing: AnyView(
                            BlockedUnblockButton(
                                person: person,
                                isUnblocking: viewModel.unblockingIDs.contains(person.id),
                                onUnblock: { personPendingUnblock = person }
                            )
                        )
                    )
                }
            }
            .padding(.bottom, FriendsLayout.bottomPadding(layout))
            .animation(
                .easeInOut(duration: BlockedUsersLayout.removeDuration),
                value: people.map(\.id)
            )
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Row (DS-032: person-row config — no BlockedPersonRow fork)

private extension BlockedPerson {
    /// Maps blocked identity onto shared person-row presentation (handle as secondary).
    var personRowModel: FriendRowModel {
        FriendRowModel(
            id: id,
            friend: FriendPuckData(
                id: id,
                name: BlockedUsersCopy.displayName(self),
                avatarPlaceholder: BlockedUsersCopy.initials(for: self),
                profileImageAssetName: imageAssetPath,
                activity: "",
                activitySymbolName: "",
                activityDisplayText: "",
                availability: .unavailable,
                venueStatusText: BlockedUsersCopy.displayHandle(self),
                lastUpdated: ""
            ),
            groupLabel: nil
        )
    }
}

private struct BlockedUnblockButton: View {
    let person: BlockedPerson
    let isUnblocking: Bool
    let onUnblock: () -> Void

    var body: some View {
        Button(action: onUnblock) {
            Text(BlockedUsersCopy.unblockButton)
                .font(.caption.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)
                .padding(.horizontal, BlockedUsersLayout.actionHorizontalPadding)
                .padding(.vertical, BlockedUsersLayout.actionVerticalPadding)
                .background(PushControlColors.activeFill, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isUnblocking)
        .opacity(isUnblocking ? BlockedUsersLayout.disabledOpacity : 1)
        .accessibilityLabel("Unblock \(BlockedUsersCopy.displayName(person))")
    }
}

// MARK: - Copy & layout

private enum BlockedUsersCopy {
    static let title = "Blocked"
    static let subtitle = "People you've blocked"
    static let unblockButton = "Unblock"
    static let unblockMessage =
        "You can send a friend request again later. Friendship is not restored automatically."

    static func displayName(_ person: BlockedPerson) -> String {
        let name = person.firstName
        guard let first = name.first else { return name }
        return String(first).uppercased() + name.dropFirst()
    }

    static func displayHandle(_ person: BlockedPerson) -> String {
        let raw = person.handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return "" }
        return raw.hasPrefix("@") ? raw : "@\(raw)"
    }

    static func initials(for person: BlockedPerson) -> String {
        String(person.firstName.prefix(2)).uppercased()
    }
}

private enum BlockedUsersLayout {
    static let contentTopSpacing: CGFloat = 6
    static let stateSpacing: CGFloat = 10
    static let stateIconSize: CGFloat = 28
    static let stateHorizontalPadding: CGFloat = 36
    static let actionHorizontalPadding: CGFloat = 12
    static let actionVerticalPadding: CGFloat = 7
    static let disabledOpacity = 0.55
    static let removeDuration: Double = 0.32
}

#if DEBUG
struct BlockedUsersView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            NavigationStack {
                BlockedUsersView()
            }
        }
    }
}
#endif
