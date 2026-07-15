import Combine
import Foundation

@MainActor
final class AlertsViewModel: ObservableObject {
    @Published private(set) var loadState: LoadState<[FriendRequestAlertModel]> = .idle
    @Published private(set) var requests: [FriendRequestAlertModel] = []
    @Published private(set) var resolvingIDs: Set<FriendRequest.ID> = []

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

    private func resolve(_ request: FriendRequestAlertModel, accepting: Bool) async {
        guard resolvingIDs.insert(request.id).inserted else { return }
        defer { resolvingIDs.remove(request.id) }
        do {
            if accepting {
                try await repository.acceptFriendRequest(id: request.id)
            } else {
                try await repository.denyFriendRequest(id: request.id)
            }
            await load()
        } catch {
            loadState = .failed(error)
        }
    }
}
