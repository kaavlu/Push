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

    static func prepareLive(client: SupabaseClient, currentUserID: Person.ID) async throws -> AppDataContainer {
        let store = LiveDataStore(loader: SupabaseLiveDataLoader(client: client))
        return try await preparedLive(
            store: store,
            currentUserID: currentUserID,
            photoStorage: SupabaseProfilePhotoStorage(client: client)
        )
    }

    static func prepareLive(loader: LiveDataLoading, currentUserID: Person.ID) async throws -> AppDataContainer {
        let store = LiveDataStore(loader: loader)
        return try await preparedLive(store: store, currentUserID: currentUserID, photoStorage: nil)
    }

    private static func preparedLive(
        store: LiveDataStore,
        currentUserID: Person.ID,
        photoStorage: ProfilePhotoStoring?
    ) async throws -> AppDataContainer {
        try await store.warm()
        let container = live(store: store, currentUserID: currentUserID, photoStorage: photoStorage)
        _ = try await container.friends.currentUser()
        return container
    }

    static func installPreparedLive(_ container: AppDataContainer) {
        shared = container
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
    let alerts: AlertRepository
    let referenceDate: Date

    let currentUserID: Person.ID

    /// Prepared live mode publishes snapshot write-through revisions. The fallback
    /// subject keeps the synchronous, unprepared constructor useful in isolation tests.
    private let liveRevision = CurrentValueSubject<Int, Never>(0)
    private let liveStore: LiveDataStore?

    /// The store's current mutation revision.
    var storeRevision: Int { database?.revision ?? liveStore?.revision ?? liveRevision.value }

    /// Fires with the new revision after each store mutation. `dropFirst()`
    /// skips the initial published value so only real mutations notify.
    func onStoreChange(_ handler: @escaping (Int) -> Void) -> AnyCancellable {
        if let database { return database.$revision.dropFirst().sink(receiveValue: handler) }
        if let liveStore { return liveStore.onChange(handler) }
        return liveRevision.dropFirst().sink(receiveValue: handler)
    }

    /// MOCK: unchanged behavior — InMemoryDatabase + Local* repos.
    init(seed: SeedData, referenceDate: Date = Date()) {
        let database = InMemoryDatabase(seed: seed)
        self.database = database
        self.currentUserID = database.currentUserID
        self.referenceDate = referenceDate
        self.liveStore = nil
        self.friends = LocalFriendRepository(database: database)
        self.groups = LocalGroupRepository(database: database)
        self.pushes = LocalPushRepository(database: database)
        self.profile = LocalProfileRepository(database: database)
        self.sharing = LocalSharingRepository(database: database)
        self.feed = LocalFeedRepository(database: database)
        self.alerts = LocalAlertRepository(database: database)
    }

    /// LIVE: Supabase-backed reads; identity from the auth session.
    static func live(client: SupabaseClient, currentUserID: Person.ID,
                     referenceDate: Date = Date()) -> AppDataContainer {
        live(
            store: LiveDataStore(loader: SupabaseLiveDataLoader(client: client)),
            currentUserID: currentUserID,
            referenceDate: referenceDate,
            photoStorage: SupabaseProfilePhotoStorage(client: client)
        )
    }

    private static func live(
        store: LiveDataStore,
        currentUserID: Person.ID,
        referenceDate: Date = Date(),
        photoStorage: ProfilePhotoStoring? = nil
    ) -> AppDataContainer {
        AppDataContainer(
            currentUserID: currentUserID,
            referenceDate: referenceDate,
            liveStore: store,
            friends: SupabaseFriendRepository(store: store, currentUserID: currentUserID),
            groups: SupabaseGroupRepository(store: store),
            pushes: SupabasePushRepository(store: store, currentUserID: currentUserID),
            profile: SupabaseProfileRepository(
                store: store, currentUserID: currentUserID, photoStorage: photoStorage
            ),
            sharing: SupabaseSharingRepository(store: store),
            feed: EmptyLiveFeedRepository(),
            alerts: SupabaseAlertRepository(store: store, currentUserID: currentUserID)
        )
    }

    private init(currentUserID: Person.ID, referenceDate: Date, liveStore: LiveDataStore,
                 friends: FriendRepository, groups: GroupRepository, pushes: PushRepository,
                 profile: ProfileRepository, sharing: SharingRepository, feed: FeedRepository,
                 alerts: AlertRepository) {
        self.database = nil
        self.currentUserID = currentUserID
        self.referenceDate = referenceDate
        self.liveStore = liveStore
        self.friends = friends; self.groups = groups; self.pushes = pushes
        self.profile = profile; self.sharing = sharing; self.feed = feed
        self.alerts = alerts
    }
}
