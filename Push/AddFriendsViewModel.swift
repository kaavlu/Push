import Combine
import Foundation

@MainActor
final class AddFriendsViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var contentState: AddFriendsContentState = .prompt
    @Published private(set) var actingIDs: Set<Person.ID> = []

    private let friends: FriendRepository
    private let alerts: AlertRepository
    private var containerForRefresh: AppDataContainer?
    private var storeChangeSub: AnyCancellable?
    private var searchTask: Task<Void, Never>?
    private var lastSeenRevision = 0
    private var lastQuery = ""

    init(friends: FriendRepository, alerts: AlertRepository) {
        self.friends = friends
        self.alerts = alerts
    }

    convenience init(container: AppDataContainer? = nil) {
        let container = container ?? .shared
        self.init(friends: container.friends, alerts: container.alerts)
        containerForRefresh = container
        storeChangeSub = container.onStoreChange { [weak self] revision in
            guard let self, revision != self.lastSeenRevision else { return }
            Task { await self.refreshIfNeeded() }
        }
    }

    func onSearchTextChanged(_ text: String) {
        searchText = text
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= AddFriendsLayout.minQueryLength else {
            lastQuery = ""
            contentState = .prompt
            return
        }
        contentState = .loading
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: AddFriendsLayout.searchDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            await self?.performSearch(query: trimmed)
        }
    }

    func sendRequest(to row: AddFriendRowModel) async {
        guard actingIDs.insert(row.id).inserted else { return }
        defer { actingIDs.remove(row.id) }
        // Optimistic outgoing pending.
        applyOptimistic(rowID: row.id) { result in
            PersonSearchResult(
                person: result.person,
                handle: result.handle,
                relation: .outgoingPending(requestID: "local-\(row.id)")
            )
        }
        do {
            try await friends.sendFriendRequest(to: row.id)
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
            await performSearch(query: lastQuery)
        } catch {
            contentState = .failed
        }
    }

    func accept(row: AddFriendRowModel) async {
        guard case .incomingPending(let requestID) = row.relation else { return }
        guard actingIDs.insert(row.id).inserted else { return }
        defer { actingIDs.remove(row.id) }
        applyOptimistic(rowID: row.id) { result in
            PersonSearchResult(person: result.person, handle: result.handle, relation: .friends)
        }
        do {
            try await alerts.acceptFriendRequest(id: requestID)
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
            await performSearch(query: lastQuery)
        } catch {
            contentState = .failed
        }
    }

    func deny(row: AddFriendRowModel) async {
        guard case .incomingPending(let requestID) = row.relation else { return }
        guard actingIDs.insert(row.id).inserted else { return }
        defer { actingIDs.remove(row.id) }
        do {
            try await alerts.denyFriendRequest(id: requestID)
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
            await performSearch(query: lastQuery)
        } catch {
            contentState = .failed
        }
    }

    func retry() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= AddFriendsLayout.minQueryLength else {
            contentState = .prompt
            return
        }
        await performSearch(query: trimmed)
    }

    private func refreshIfNeeded() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= AddFriendsLayout.minQueryLength else { return }
        await performSearch(query: trimmed)
    }

    private func performSearch(query: String) async {
        lastQuery = query
        // Keep previous results while refreshing after a mutation.
        if case .results = contentState {} else {
            contentState = .loading
        }
        do {
            let rows = try await friends.searchPeople(query: query)
                .map(AddFriendRowModel.init)
            contentState = rows.isEmpty ? .noResults : .results(rows)
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
        } catch {
            contentState = .failed
        }
    }

    private func applyOptimistic(
        rowID: Person.ID,
        transform: (PersonSearchResult) -> PersonSearchResult
    ) {
        guard case .results(let rows) = contentState else { return }
        let updated = rows.map { row -> AddFriendRowModel in
            guard row.id == rowID else { return row }
            return AddFriendRowModel(result: transform(row.result))
        }
        contentState = .results(updated)
    }
}
