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
    @Published private(set) var resolvingIDs: Set<FriendRequest.ID> = []
    @Published private(set) var cardPhases: [FriendRequest.ID: AlertCardPhase] = [:]

    private let repository: AlertRepository
    private var containerForRefresh: AppDataContainer?
    private var storeChangeSub: AnyCancellable?
    private var lastSeenRevision = 0

    var unreadCount: Int { requests.filter(\.request.isUnread).count }
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

        loadState = .loading
        do {
            let models = try await repository.incomingFriendRequests()
                .map(FriendRequestAlertModel.init)
            requests = models
            loadState = .loaded(models)
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
        } catch {
            loadState = .failed(error)
        }
    }

    func accept(_ request: FriendRequestAlertModel) async {
        await resolve(request, accepting: true)
    }

    func deny(_ request: FriendRequestAlertModel) async {
        await resolve(request, accepting: false)
    }

    func phase(for id: FriendRequest.ID) -> AlertCardPhase? {
        cardPhases[id]
    }

    private func resolve(_ request: FriendRequestAlertModel, accepting: Bool) async {
        guard resolvingIDs.insert(request.id).inserted else { return }
        defer {
            resolvingIDs.remove(request.id)
            cardPhases.removeValue(forKey: request.id)
        }

        do {
            if accepting {
                try await repository.acceptFriendRequest(id: request.id)
                cardPhases[request.id] = .added
                try await Task.sleep(nanoseconds: AlertsLayout.addedHoldNanoseconds)
            } else {
                try await repository.denyFriendRequest(id: request.id)
                cardPhases[request.id] = .denying
                try await Task.sleep(nanoseconds: AlertsLayout.denyCollapseNanoseconds)
            }
            removeResolved(request.id)
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
        } catch {
            loadState = .failed(error)
        }
    }

    private func removeResolved(_ id: FriendRequest.ID) {
        requests.removeAll { $0.id == id }
        loadState = .loaded(requests)
    }
}
