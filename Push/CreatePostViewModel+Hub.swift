//
//  CreatePostViewModel+Hub.swift
//  Push
//
//  Repository-backed Create Post hub (architecture S7 §6.2–6.3): Existing
//  Moments from `MomentRepository.hubMoments()`, Past Pushes from the Push
//  history, and the friend catalog from the social graph. No fixtures.
//

import Foundation

@MainActor
extension CreatePostViewModel {

    var momentsRepo: MomentRepository? { momentsOverride ?? container?.moments }

    var mediaStorage: MomentMediaStoring? { mediaStorageOverride ?? container?.momentMedia }

    /// False only on the preview seam, which has no repositories at all.
    var isRepositoryBacked: Bool { container != nil || momentsOverride != nil }

    /// Shared surface states for the visible segment (DS-070). Rows win over a
    /// refresh in flight, so switching segments never blanks loaded content.
    var hubContentPhase: SurfaceContentPhase {
        guard visibleChooserItems.isEmpty else { return .content }
        switch hubLoadState {
        case .idle, .loading: return .loading
        case .failed: return .failed
        case .loaded: return .empty
        }
    }

    // MARK: - Loading

    /// Soft load: existing rows stay on screen while the reload is in flight.
    func load(now: Date = Date()) async {
        guard let container, let momentsRepo else { return }
        if hubLoadState.value == nil { hubLoadState = .loading }
        do {
            let people = try await loadPeople(container: container)
            let hub = try await momentsRepo.hubMoments()
            let plans = try await historicalPlans(container: container, now: now)
            let responses = try await container.pushes.responses()
            let places = try await container.pushes.allPlaces()

            peopleByID = people
            // Every Push slot this viewer can see is already taken.
            momentPushIDs = Set(hub.compactMap(\.moment.pushID))
            existingMoments = CreatePostHubBuilder.existingMoments(
                from: hub, people: people, now: now
            )
            pastPushes = CreatePostHubBuilder.pastPushes(
                plans: plans,
                responses: responses,
                momentPushIDs: momentPushIDs,
                peopleByID: people,
                placesByID: Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) }),
                viewerID: container.currentUserID,
                now: now
            )
            applyFriendCatalog(friendIDs: people.keys.filter { $0 != container.currentUserID })
            hubLoadState = .loaded(())
            stampStoreRevision()
        } catch {
            hubLoadState = .failed(error)
        }
    }

    /// Hub state after a publish or a pull-to-refresh.
    func refresh() async {
        try? await container?.refreshSession()
        await load()
    }

    // MARK: - Internals

    private func loadPeople(container: AppDataContainer) async throws -> [Person.ID: Person] {
        let friends = try await container.friends.friends()
        let user = try await container.friends.currentUser()
        return Dictionary(uniqueKeysWithValues: (friends + [user]).map { ($0.id, $0) })
    }

    /// The chooser looks back two months: `historicalPlans` is month-scoped, and
    /// a Push that finished late last month is still worth turning into a Moment.
    private func historicalPlans(
        container: AppDataContainer, now: Date
    ) async throws -> [PushPlan] {
        var plans = try await container.pushes.historicalPlans(forMonthContaining: now)
        if let previousMonth = Calendar.current.date(
            byAdding: .month, value: -1, to: now
        ) {
            let earlier = try await container.pushes.historicalPlans(
                forMonthContaining: previousMonth
            )
            let known = Set(plans.map(\.id))
            plans += earlier.filter { !known.contains($0.id) }
        }
        return plans
    }

    /// Tagging targets are real people: the viewer's accepted friends, in graph
    /// order, keyed by `Person.ID` so a selection maps straight to a tag id.
    private func applyFriendCatalog(friendIDs: some Sequence<Person.ID>) {
        let catalog = friendIDs
            .compactMap { peopleByID[$0] }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            .map { person in
                PushRecipientItem(
                    id: person.id,
                    name: person.displayName,
                    memberCount: nil,
                    imageAssetName: person.imageAssetPath,
                    initials: person.initials,
                    isGroup: false
                )
            }
        baseAvailableFriends = catalog
        // Keeps anyone already tagged on the open draft selectable.
        mergeParticipantsIntoAvailableFriends(displayParticipants)
    }
}
