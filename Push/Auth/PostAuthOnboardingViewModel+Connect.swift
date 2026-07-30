// Push/Auth/PostAuthOnboardingViewModel+Connect.swift
import Foundation

extension PostAuthOnboardingViewModel {
    // MARK: - Contacts → find people

    /// Optional contacts access; denied/restricted still advances to find people.
    func enableContacts() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        let granted = await contacts.requestAccess()
        var hints: [ContactMatchHint] = []
        if granted {
            hints = (try? await contacts.fetchMatchHints(limit: Limit.contactHintFetch)) ?? []
        }
        await loadPeopleAndAdvance(contactHints: hints)
    }

    func skipContacts() async {
        guard !isBusy else { return }
        errorMessage = nil
        await loadPeopleAndAdvance(contactHints: [])
    }

    /// Primary CTA on contacts primer — requests access when possible.
    func continueFromContacts() async {
        await enableContacts()
    }

    // MARK: - Find people

    func toggleFriend(_ id: Person.ID) async {
        if addedIDs.contains(id) {
            // Already requested this session — leave pending; no cancel UX on this step.
            return
        }
        guard actingIDs.insert(id).inserted else { return }
        defer { actingIDs.remove(id) }
        errorMessage = nil
        do {
            _ = try await container.friends.sendFriendRequest(to: id)
            addedIDs.insert(id)
            if let index = people.firstIndex(where: { $0.id == id }) {
                let person = people[index]
                let requestID = "pending-\(id)"
                people[index] = OnboardingDiscoverPerson(
                    result: PersonSearchResult(
                        person: person.result.person,
                        handle: person.handle,
                        relation: .outgoingPending(requestID: requestID)
                    )
                )
            }
        } catch {
            errorMessage = Copy.friendRequestFailed
        }
    }

    func isAdded(_ id: Person.ID) -> Bool {
        addedIDs.contains(id) || {
            if case .outgoingPending = people.first(where: { $0.id == id })?.relation {
                return true
            }
            return false
        }()
    }

    func continueFromFindPeople() async {
        await finishOnboarding()
    }

    func loadPeopleAndAdvance(contactHints: [ContactMatchHint]) async {
        isLoadingPeople = true
        errorMessage = nil
        defer { isLoadingPeople = false }
        do {
            let hits = try await resolveFindPeopleResults(contactHints: contactHints)
            people = hits.map { OnboardingDiscoverPerson(result: $0) }
        } catch {
            people = []
            errorMessage = Copy.friendsLoadFailed
        }
        screen = .findPeople
    }

    /// Prefer contact-name search hits; fall back to discover when empty.
    func resolveFindPeopleResults(
        contactHints: [ContactMatchHint]
    ) async throws -> [PersonSearchResult] {
        let fromContacts = await searchFromContactHints(contactHints)
        if !fromContacts.isEmpty { return fromContacts }
        return try await container.friends.discoverPeople(limit: Limit.discoverCount)
    }

    func searchFromContactHints(
        _ hints: [ContactMatchHint]
    ) async -> [PersonSearchResult] {
        var seen = Set<Person.ID>()
        var results: [PersonSearchResult] = []
        let queries = uniqueSearchQueries(from: hints)
        for query in queries.prefix(Limit.contactSearchQueries) {
            guard let hits = try? await container.friends.searchPeople(query: query) else {
                continue
            }
            for hit in hits where seen.insert(hit.id).inserted {
                results.append(hit)
                if results.count >= Limit.discoverCount { return results }
            }
        }
        return results
    }

    func uniqueSearchQueries(from hints: [ContactMatchHint]) -> [String] {
        var seen = Set<String>()
        var queries: [String] = []
        for hint in hints {
            let trimmed = hint.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let firstToken = hint.displayName
                .split(whereSeparator: { $0.isWhitespace })
                .first
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                ?? ""
            let query = firstToken.count >= 2 ? firstToken : trimmed
            guard query.count >= 2 else { continue }
            let key = query.lowercased()
            if seen.insert(key).inserted {
                queries.append(query)
            }
        }
        return queries
    }

}
