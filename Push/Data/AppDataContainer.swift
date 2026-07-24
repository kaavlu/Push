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
        installPreparedLive(container)
        return container
    }

    static func prepareLive(client: SupabaseClient, currentUserID: Person.ID) async throws -> AppDataContainer {
        let store = LiveDataStore(loader: SupabaseLiveDataLoader(client: client))
        return try await preparedLive(
            store: store,
            currentUserID: currentUserID,
            photoStorage: SupabaseProfilePhotoStorage(client: client),
            groupPhotoStorage: SupabaseGroupPhotoStorage(client: client)
        )
    }

    static func prepareLive(loader: LiveDataLoading, currentUserID: Person.ID) async throws -> AppDataContainer {
        let store = LiveDataStore(loader: loader)
        return try await preparedLive(
            store: store,
            currentUserID: currentUserID,
            photoStorage: nil,
            groupPhotoStorage: nil
        )
    }

    private static func preparedLive(
        store: LiveDataStore,
        currentUserID: Person.ID,
        photoStorage: ProfilePhotoStoring?,
        groupPhotoStorage: GroupPhotoStoring?
    ) async throws -> AppDataContainer {
        try await store.warm()
        let container = live(
            store: store,
            currentUserID: currentUserID,
            photoStorage: photoStorage,
            groupPhotoStorage: groupPhotoStorage
        )
        _ = try await container.friends.currentUser()
        return container
    }

    /// Install a prepared live container. Shuts down the previous session first
    /// (no unpublish — mid-session swap of the same user must not clear presence).
    static func installPreparedLive(_ container: AppDataContainer) {
        shared.shutdownLocationSession()
        shared = container
        Task { await container.locationSession?.startIfEligible() }
    }

    /// Sign-out / delete-account path: optional best-effort unpublish → session
    /// shutdown → safe idle mock container. Never blocks forever on network.
    /// - Parameter attemptUnpublish: `true` for sign-out (JWT still valid).
    ///   `false` after successful account deletion (server cascade owns presence).
    static func shutdownSharedAndReinstallMock(attemptUnpublish: Bool = true) async {
        if attemptUnpublish {
            await shared.teardownLocationForSignOut()
        } else {
            shared.shutdownLocationSession()
        }
        shared = AppDataContainer(seed: .standard())
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

    /// App-lifetime location pipeline. Independent of map tab visibility.
    /// Tests may inject a `FakeLocationSession`; production uses factory defaults.
    private(set) var locationSession: LocationSessioning?

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

    /// Live: re-warm the session snapshot. Mock: no-op success.
    func refreshSession() async throws {
        guard let liveStore else { return }
        try await liveStore.refresh()
    }

    /// Stop the location pipeline without unpublish (container swap / idle).
    func shutdownLocationSession() {
        locationSession?.shutdown()
        locationSession = nil
    }

    /// Sign-out order: best-effort unpublish while JWT may still be valid, then shutdown.
    func teardownLocationForSignOut() async {
        await locationSession?.unpublishBestEffort()
        shutdownLocationSession()
    }

    /// MOCK: unchanged behavior — InMemoryDatabase + Local* repos.
    /// `clock` is for lifecycle filtering in tests that freeze seed time; app uses wall clock.
    init(
        seed: SeedData,
        referenceDate: Date = Date(),
        clock: (@Sendable () -> Date)? = nil,
        locationSession: LocationSessioning? = nil
    ) {
        let database = InMemoryDatabase(seed: seed)
        self.database = database
        self.currentUserID = database.currentUserID
        self.referenceDate = referenceDate
        self.liveStore = nil
        self.friends = LocalFriendRepository(database: database)
        self.groups = LocalGroupRepository(database: database)
        let resolvedClock = clock ?? { Date() }
        self.pushes = LocalPushRepository(database: database, clock: resolvedClock)
        self.profile = LocalProfileRepository(database: database)
        self.sharing = LocalSharingRepository(database: database)
        self.feed = LocalFeedRepository(database: database)
        self.alerts = LocalAlertRepository(database: database)
        // Explicit nil means "build default"; pass FakeLocationSession for tests.
        // Use a sentinel-free approach: optional with default factory when not injected.
        if let locationSession {
            self.locationSession = locationSession
        } else {
            // Mock presence writes go through LocalPresenceSync so Ghost/unpublish
            // and sim location update friend-visible rows (Issue #76).
            let sync = LocalPresenceSync(database: database)
            self.locationSession = LocationSessionFactory.makeDefault(
                personID: database.currentUserID,
                availabilityProvider: { [weak database] in
                    database?.profile.chosenAvailability
                },
                sync: sync
            )
        }
    }

    /// LIVE: Supabase-backed reads; identity from the auth session.
    static func live(client: SupabaseClient, currentUserID: Person.ID,
                     referenceDate: Date = Date()) -> AppDataContainer {
        live(
            store: LiveDataStore(loader: SupabaseLiveDataLoader(client: client)),
            currentUserID: currentUserID,
            referenceDate: referenceDate,
            photoStorage: SupabaseProfilePhotoStorage(client: client),
            groupPhotoStorage: SupabaseGroupPhotoStorage(client: client)
        )
    }

    private static func live(
        store: LiveDataStore,
        currentUserID: Person.ID,
        referenceDate: Date = Date(),
        photoStorage: ProfilePhotoStoring? = nil,
        groupPhotoStorage: GroupPhotoStoring? = nil,
        locationSession: LocationSessioning? = nil
    ) -> AppDataContainer {
        let resolvedSession = locationSession ?? makeLiveLocationSession(
            store: store, currentUserID: currentUserID
        )
        return AppDataContainer(
            currentUserID: currentUserID,
            referenceDate: referenceDate,
            liveStore: store,
            friends: SupabaseFriendRepository(store: store, currentUserID: currentUserID),
            groups: SupabaseGroupRepository(store: store, photoStorage: groupPhotoStorage),
            pushes: SupabasePushRepository(store: store, currentUserID: currentUserID),
            profile: SupabaseProfileRepository(
                store: store, currentUserID: currentUserID, photoStorage: photoStorage
            ),
            sharing: SupabaseSharingRepository(store: store),
            feed: EmptyLiveFeedRepository(),
            alerts: SupabaseAlertRepository(store: store, currentUserID: currentUserID),
            locationSession: resolvedSession
        )
    }

    /// Live presence writes go through `SupabasePresenceSync` (buffer + upsert).
    /// Availability for drafts is always mirrored from the warm profile cache.
    private static func makeLiveLocationSession(
        store: LiveDataStore,
        currentUserID: Person.ID
    ) -> LocationSession {
        let sync = SupabasePresenceSync(userID: currentUserID, store: store)
        return LocationSessionFactory.makeDefault(
            personID: currentUserID,
            availabilityProvider: {
                store.cachedAvailability(userID: currentUserID)
            },
            sync: sync
        )
    }

    private init(
        currentUserID: Person.ID,
        referenceDate: Date,
        liveStore: LiveDataStore,
        friends: FriendRepository,
        groups: GroupRepository,
        pushes: PushRepository,
        profile: ProfileRepository,
        sharing: SharingRepository,
        feed: FeedRepository,
        alerts: AlertRepository,
        locationSession: LocationSessioning?
    ) {
        self.database = nil
        self.currentUserID = currentUserID
        self.referenceDate = referenceDate
        self.liveStore = liveStore
        self.friends = friends; self.groups = groups; self.pushes = pushes
        self.profile = profile; self.sharing = sharing; self.feed = feed
        self.alerts = alerts
        self.locationSession = locationSession
    }
}
