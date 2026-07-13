//
//  AppDataContainer.swift
//  Push
//
//  Composition root. View models default to `.shared` so previews and the
//  app work without wiring; tests build isolated containers per case.
//

import Combine
import Foundation
import Supabase

@MainActor
final class AppDataContainer {
    /// Active container. Mock by default; `RootView` installs a live one at
    /// bootstrap, before any ViewModel (which defaults to `.shared`) is created.
    static private(set) var shared = AppDataContainer(seed: .standard())

    /// Replace `.shared` with a live, session-scoped container. Called once at bootstrap.
    @discardableResult
    static func installLive(client: SupabaseClient, currentUserID: Person.ID) -> AppDataContainer {
        let container = live(client: client, currentUserID: currentUserID)
        shared = container
        return container
    }

    /// Present only in mock mode; live mode has no local store (reads-only Day 1).
    /// Implicitly-unwrapped so existing mock tests that touch `.database` compile unchanged.
    let database: InMemoryDatabase!
    let friends: FriendRepository
    let groups: GroupRepository
    let pushes: PushRepository
    let profile: ProfileRepository
    let sharing: SharingRepository
    let feed: FeedRepository
    let referenceDate: Date

    let currentUserID: Person.ID

    /// Live mode has no InMemoryDatabase, so revisions come from a local subject
    /// (a no-op on Day 1 — live social data is reads-only).
    private let liveRevision = CurrentValueSubject<Int, Never>(0)

    /// The store's current mutation revision.
    var storeRevision: Int { database?.revision ?? liveRevision.value }

    /// Fires with the new revision after each store mutation. `dropFirst()`
    /// skips the initial published value so only real mutations notify.
    func onStoreChange(_ handler: @escaping (Int) -> Void) -> AnyCancellable {
        if let database { return database.$revision.dropFirst().sink(receiveValue: handler) }
        return liveRevision.dropFirst().sink(receiveValue: handler)
    }

    /// MOCK: unchanged behavior — InMemoryDatabase + Local* repos.
    init(seed: SeedData, referenceDate: Date = Date()) {
        let database = InMemoryDatabase(seed: seed)
        self.database = database
        self.currentUserID = database.currentUserID
        self.referenceDate = referenceDate
        self.friends = LocalFriendRepository(database: database)
        self.groups = LocalGroupRepository(database: database)
        self.pushes = LocalPushRepository(database: database)
        self.profile = LocalProfileRepository(database: database)
        self.sharing = LocalSharingRepository(database: database)
        self.feed = LocalFeedRepository(database: database)
    }

    /// LIVE: Supabase-backed reads; identity from the auth session.
    static func live(client: SupabaseClient, currentUserID: Person.ID,
                     referenceDate: Date = Date()) -> AppDataContainer {
        AppDataContainer(
            currentUserID: currentUserID,
            referenceDate: referenceDate,
            friends: SupabaseFriendRepository(client: client, currentUserID: currentUserID),
            groups: SupabaseGroupRepository(client: client),
            pushes: EmptyLivePushRepository(),
            profile: SupabaseProfileRepository(client: client, currentUserID: currentUserID),
            sharing: SupabaseSharingRepository(client: client),
            feed: EmptyLiveFeedRepository()
        )
    }

    private init(currentUserID: Person.ID, referenceDate: Date,
                 friends: FriendRepository, groups: GroupRepository, pushes: PushRepository,
                 profile: ProfileRepository, sharing: SharingRepository, feed: FeedRepository) {
        self.database = nil
        self.currentUserID = currentUserID
        self.referenceDate = referenceDate
        self.friends = friends; self.groups = groups; self.pushes = pushes
        self.profile = profile; self.sharing = sharing; self.feed = feed
    }
}
