import Combine
import Foundation

@MainActor
final class AddFriendsViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var contentState: AddFriendsContentState = .prompt
    @Published private(set) var actingIDs: Set<Person.ID> = []
    @Published private(set) var actionError: ActionErrorState?

    private let friends: FriendRepository
    private let alerts: AlertRepository
    private var containerForRefresh: AppDataContainer?
    private var storeChangeSub: AnyCancellable?
    private var searchTask: Task<Void, Never>?
    private var lastSeenRevision = 0
    private var lastQuery = ""
    private var pendingMutation: PendingMutation?

    private enum PendingMutation {
        case send(AddFriendRowModel)
        case cancel(AddFriendRowModel)
        case accept(AddFriendRowModel)
        case deny(AddFriendRowModel)
    }

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
        guard row.relation == .none else { return }
        guard actingIDs.insert(row.id).inserted else { return }
        defer { actingIDs.remove(row.id) }
        let previous = row.result
        applyOptimistic(rowID: row.id) { result in
            PersonSearchResult(
                person: result.person,
                handle: result.handle,
                relation: .outgoingPending(requestID: "local-\(row.id)")
            )
        }
        do {
            let requestID = try await friends.sendFriendRequest(to: row.id)
            if !requestID.isEmpty {
                applyOptimistic(rowID: row.id) { result in
                    PersonSearchResult(
                        person: result.person,
                        handle: result.handle,
                        relation: .outgoingPending(requestID: requestID)
                    )
                }
            }
            clearMutationError()
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
            await performSearch(query: lastQuery)
        } catch {
            restore(previous)
            pendingMutation = .send(row)
            actionError = ActionErrorState(message: AddFriendsMutationCopy.sendFailed)
        }
    }

    func cancelRequest(for row: AddFriendRowModel) async {
        guard case .outgoingPending(let requestID) = row.relation else { return }
        guard actingIDs.insert(row.id).inserted else { return }
        defer { actingIDs.remove(row.id) }
        let previous = row.result
        applyOptimistic(rowID: row.id) { result in
            PersonSearchResult(person: result.person, handle: result.handle, relation: .none)
        }
        do {
            try await friends.cancelFriendRequest(id: requestID)
            clearMutationError()
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
            await performSearch(query: lastQuery)
        } catch {
            restore(previous)
            pendingMutation = .cancel(row)
            actionError = ActionErrorState(message: AddFriendsMutationCopy.cancelFailed)
        }
    }

    func accept(row: AddFriendRowModel) async {
        guard case .incomingPending(let requestID) = row.relation else { return }
        guard actingIDs.insert(row.id).inserted else { return }
        defer { actingIDs.remove(row.id) }
        let previous = row.result
        applyOptimistic(rowID: row.id) { result in
            PersonSearchResult(person: result.person, handle: result.handle, relation: .friends)
        }
        do {
            try await alerts.acceptFriendRequest(id: requestID)
            clearMutationError()
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
            await performSearch(query: lastQuery)
        } catch {
            restore(previous)
            pendingMutation = .accept(row)
            actionError = ActionErrorState(message: AddFriendsMutationCopy.acceptFailed)
        }
    }

    func deny(row: AddFriendRowModel) async {
        guard case .incomingPending(let requestID) = row.relation else { return }
        guard actingIDs.insert(row.id).inserted else { return }
        defer { actingIDs.remove(row.id) }
        let previous = row.result
        applyOptimistic(rowID: row.id) { result in
            PersonSearchResult(person: result.person, handle: result.handle, relation: .none)
        }
        do {
            try await alerts.denyFriendRequest(id: requestID)
            clearMutationError()
            lastSeenRevision = containerForRefresh?.storeRevision ?? lastSeenRevision
            await performSearch(query: lastQuery)
        } catch {
            restore(previous)
            pendingMutation = .deny(row)
            actionError = ActionErrorState(message: AddFriendsMutationCopy.denyFailed)
        }
    }

    func dismissActionError() {
        actionError = nil
        pendingMutation = nil
    }

    func retryLastAction() async {
        guard let pendingMutation else { return }
        switch pendingMutation {
        case .send(let row): await sendRequest(to: row)
        case .cancel(let row): await cancelRequest(for: row)
        case .accept(let row): await accept(row: row)
        case .deny(let row): await deny(row: row)
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
            // Do not present network errors as empty results.
            if case .results = contentState {
                actionError = ActionErrorState(message: AddFriendsMutationCopy.searchRefreshFailed)
            } else {
                contentState = .failed
            }
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

    private func restore(_ previous: PersonSearchResult) {
        applyOptimistic(rowID: previous.id) { _ in previous }
    }

    private func clearMutationError() {
        actionError = nil
        pendingMutation = nil
    }
}

enum AddFriendsMutationCopy {
    static let sendFailed = "Couldn't send the request. Try again."
    static let cancelFailed = "Couldn't cancel the request. Try again."
    static let acceptFailed = "Couldn't accept the request. Try again."
    static let denyFailed = "Couldn't decline the request. Try again."
    static let searchRefreshFailed = "Couldn't refresh results. Try again."
}
