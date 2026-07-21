import Combine
import Foundation

/// Transient card chrome after Accept/Deny while the row still occupies the list.
enum AlertCardPhase: Equatable {
    /// Accept succeeded — show "Added" before removal.
    case added
    /// Deny succeeded — fade/collapse before removal.
    case denying
}

@MainActor
final class AlertsViewModel: ObservableObject {
    @Published private(set) var loadState: LoadState<[FriendRequestAlertModel]> = .idle
    @Published private(set) var requests: [FriendRequestAlertModel] = []
    @Published private(set) var groupInvites: [GroupInvite] = []
    // Keyed by String rather than FriendRequest.ID/GroupInvite.ID specifically —
    // both resolve to String, and one shared guard covers friend requests and
    // group invites so their accept/deny timing/chrome never diverges.
    @Published private(set) var resolvingIDs: Set<String> = []
    @Published private(set) var cardPhases: [String: AlertCardPhase] = [:]
    @Published private(set) var actionError: ActionErrorState?

    private let repository: AlertRepository
    private var containerForRefresh: AppDataContainer?
    private var storeChangeSub: AnyCancellable?
    private var lastSeenRevision = 0
    private var pendingResolve: PendingResolve?

    private struct PendingResolve {
        let id: String
        let accepting: Bool
        let perform: () async throws -> Void
        let removeFromList: () -> Void

        init(
            id: String,
            accepting: Bool,
            perform: @escaping () async throws -> Void,
            removeFromList: @escaping () -> Void
        ) {
            self.id = id
            self.accepting = accepting
            self.perform = perform
            self.removeFromList = removeFromList
        }
    }

    /// Group invites carry no per-row read state, so every pending invite
    /// counts toward the badge — matching how every pending friend request does.
    var unreadCount: Int {
        requests.filter(\.request.isUnread).count + groupInvites.count
    }
    var hasUnreadAlerts: Bool { unreadCount > 0 }

    init(repository: AlertRepository) {
        self.repository = repository
        Task { await load() }
    }

    convenience init(container: AppDataContainer? = nil) {
        let container = container ?? .shared
        self.init(repository: container.alerts)
        containerForRefresh = container
        storeChangeSub = container.onStoreChange { [weak self] revision in
            guard let self, revision != self.lastSeenRevision else { return }
            Task { await self.load() }
        }
    }

    func load() async {
        // Avoid wiping in-flight resolution chrome when the store mutates mid-animation.
        guard resolvingIDs.isEmpty else { return }

        // Soft load: keep last content visible while refreshing.
        if loadState.value == nil { loadState = .loading }
        do {
            let models = try await repository.incomingFriendRequests()
                .map(FriendRequestAlertModel.init)
            let invites = try await repository.incomingGroupInvites()
            requests = models
            groupInvites = invites
            loadState = .loaded(models)
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
        } catch {
            if loadState.value == nil {
                loadState = .failed(error)
            }
        }
    }

    func refresh() async {
        try? await containerForRefresh?.refreshSession()
        await load()
    }

    func dismissActionError() {
        actionError = nil
    }

    func retryLastAction() async {
        guard let pending = pendingResolve else { return }
        await resolve(
            id: pending.id,
            accepting: pending.accepting,
            perform: pending.perform,
            removeFromList: pending.removeFromList
        )
    }

    func accept(_ request: FriendRequestAlertModel) async {
        await resolve(id: request.id, accepting: true) { [repository] in
            try await repository.acceptFriendRequest(id: request.id)
        } removeFromList: { [weak self] in
            self?.removeResolvedFriendRequest(request.id)
        }
    }

    func deny(_ request: FriendRequestAlertModel) async {
        await resolve(id: request.id, accepting: false) { [repository] in
            try await repository.denyFriendRequest(id: request.id)
        } removeFromList: { [weak self] in
            self?.removeResolvedFriendRequest(request.id)
        }
    }

    func acceptGroupInvite(_ invite: GroupInvite) async {
        await resolve(id: invite.id, accepting: true) { [repository] in
            try await repository.acceptGroupInvite(id: invite.id)
        } removeFromList: { [weak self] in
            self?.removeResolvedGroupInvite(invite.id)
        }
    }

    func denyGroupInvite(_ invite: GroupInvite) async {
        await resolve(id: invite.id, accepting: false) { [repository] in
            try await repository.denyGroupInvite(id: invite.id)
        } removeFromList: { [weak self] in
            self?.removeResolvedGroupInvite(invite.id)
        }
    }

    func phase(for id: String) -> AlertCardPhase? {
        cardPhases[id]
    }

    /// Shared accept/deny machinery for both friend requests and group
    /// invites: identical in-flight guard, "Added"/denying chrome, and
    /// timing (`AlertsLayout.addedHoldNanoseconds`/`denyCollapseNanoseconds`)
    /// so the two card types never feel different to use.
    private func resolve(
        id: String,
        accepting: Bool,
        perform: @escaping () async throws -> Void,
        removeFromList: @escaping () -> Void
    ) async {
        guard resolvingIDs.insert(id).inserted else { return }
        defer {
            resolvingIDs.remove(id)
            cardPhases.removeValue(forKey: id)
        }

        do {
            try await perform()
            cardPhases[id] = accepting ? .added : .denying
            let holdNanoseconds = accepting
                ? AlertsLayout.addedHoldNanoseconds
                : AlertsLayout.denyCollapseNanoseconds
            try await Task.sleep(nanoseconds: holdNanoseconds)
            removeFromList()
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
            actionError = nil
            pendingResolve = nil
        } catch {
            // Keep the list; do not force full-screen .failed on action errors.
            pendingResolve = PendingResolve(
                id: id,
                accepting: accepting,
                perform: perform,
                removeFromList: removeFromList
            )
            actionError = ActionErrorState(
                message: accepting
                    ? AlertsMutationCopy.acceptFailed
                    : AlertsMutationCopy.denyFailed
            )
        }
    }

    private func removeResolvedFriendRequest(_ id: String) {
        requests.removeAll { $0.id == id }
        loadState = .loaded(requests)
    }

    private func removeResolvedGroupInvite(_ id: String) {
        groupInvites.removeAll { $0.id == id }
    }
}

private enum AlertsMutationCopy {
    static let acceptFailed = "Couldn't accept. Try again."
    static let denyFailed = "Couldn't decline. Try again."
}
