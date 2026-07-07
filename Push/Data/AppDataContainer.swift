//
//  AppDataContainer.swift
//  Push
//
//  Composition root. View models default to `.shared` so previews and the
//  app work without wiring; tests build isolated containers per case.
//

import Combine
import Foundation

@MainActor
final class AppDataContainer {
    static let shared = AppDataContainer(seed: .standard())

    let database: InMemoryDatabase
    let friends: FriendRepository
    let groups: GroupRepository
    let pushes: PushRepository
    let profile: ProfileRepository
    let sharing: SharingRepository
    let feed: FeedRepository
    let referenceDate: Date

    var currentUserID: Person.ID { database.currentUserID }

    /// The store's current mutation revision.
    var storeRevision: Int { database.revision }

    /// Fires with the new revision after each store mutation. `dropFirst()`
    /// skips the initial published value so only real mutations notify.
    func onStoreChange(_ handler: @escaping (Int) -> Void) -> AnyCancellable {
        database.$revision.dropFirst().sink(receiveValue: handler)
    }

    init(seed: SeedData, referenceDate: Date = Date()) {
        let database = InMemoryDatabase(seed: seed)
        self.database = database
        self.referenceDate = referenceDate
        self.friends = LocalFriendRepository(database: database)
        self.groups = LocalGroupRepository(database: database)
        self.pushes = LocalPushRepository(database: database)
        self.profile = LocalProfileRepository(database: database)
        self.sharing = LocalSharingRepository(database: database)
        self.feed = LocalFeedRepository(database: database)
    }
}
