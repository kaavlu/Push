//
//  BlockedUsersViewModel.swift
//  Push
//
//  Profile › Blocked list: load blocked people and unblock with recoverable
//  errors. Friendship is never restored on unblock — only the block edge.
//

import Combine
import Foundation

@MainActor
final class BlockedUsersViewModel: ObservableObject {
    @Published private(set) var loadState: LoadState<[BlockedPerson]> = .idle
    @Published private(set) var actionError: ActionErrorState?
    @Published private(set) var unblockingIDs: Set<Person.ID> = []

    private let friends: FriendRepository
    private var containerForRefresh: AppDataContainer?
    private var storeChangeSub: AnyCancellable?
    private var lastSeenRevision = 0
    private var pendingUnblock: BlockedPerson?

    init(friends: FriendRepository, container: AppDataContainer? = nil) {
        self.friends = friends
        if let container {
            containerForRefresh = container
            storeChangeSub = container.onStoreChange { [weak self] revision in
                guard let self, revision != self.lastSeenRevision else { return }
                Task { await self.load() }
            }
        }
    }

    convenience init(container: AppDataContainer? = nil) {
        let container = container ?? .shared
        self.init(friends: container.friends, container: container)
    }

    func load() async {
        // Soft load: keep last content visible while refreshing.
        if loadState.value == nil { loadState = .loading }
        do {
            let people = try await friends.blockedUsers()
            loadState = .loaded(people)
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
        } catch {
            if loadState.value == nil {
                loadState = .failed(error)
            }
        }
    }

    /// Pull-to-refresh: re-warm live snapshot, then reload the blocked list.
    func refresh() async {
        try? await containerForRefresh?.refreshSession()
        await load()
    }

    /// Removes the outbound block. Row stays until the write succeeds.
    func unblock(_ person: BlockedPerson) async {
        guard unblockingIDs.insert(person.id).inserted else { return }
        defer { unblockingIDs.remove(person.id) }
        do {
            try await friends.unblockUser(person.id)
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
            actionError = nil
            pendingUnblock = nil
            await load()
        } catch {
            pendingUnblock = person
            actionError = ActionErrorState(
                message: "Couldn't unblock \(displayName(for: person)). Try again."
            )
        }
    }

    func retryLastAction() async {
        guard let pendingUnblock else { return }
        await unblock(pendingUnblock)
    }

    func dismissActionError() {
        actionError = nil
    }

    private func displayName(for person: BlockedPerson) -> String {
        let name = person.firstName
        guard let first = name.first else { return name }
        return String(first).uppercased() + name.dropFirst()
    }
}
