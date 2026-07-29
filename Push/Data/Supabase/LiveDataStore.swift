import Combine
import Foundation
import Supabase

@MainActor
protocol LiveDataLoading: AnyObject {
    func loadProfiles() async throws -> [ProfileRow]
    func loadGroups() async throws -> [GroupRow]
    func loadMemberships() async throws -> [GroupMembershipRow]
    func loadPolicies() async throws -> [SharingPolicyRow]
    func updateBasics(userID: String, displayName: String, handle: String) async throws -> ProfileRow
    func updatePrivacy(userID: String, payload: ProfileSettingsPayload) async throws -> ProfileRow
    func updateAvailability(userID: String, rawValue: String) async throws -> ProfileRow
    func updateImagePath(userID: String, imageAssetPath: String?) async throws -> ProfileRow
    func loadPushes() async throws -> [PushRow]
    func loadResponses() async throws -> [PushResponseRow]
    func loadPresence() async throws -> [CurrentPresenceRow]
    func upsertCurrentPresence(_ payload: CurrentPresenceUpsertPayload) async throws -> CurrentPresenceRow
    func unpublishCurrentPresence() async throws
    func insertPush(_ payload: PushInsertPayload) async throws -> PushRow
    func updatePush(id: String, payload: PushUpdatePayload) async throws -> PushRow
    func cancelPush(id: String, payload: PushCancelPayload) async throws -> PushRow
    func deletePush(id: String) async throws
    func insertResponses(_ payloads: [PushResponsePayload]) async throws
    func upsertResponse(_ payload: PushResponsePayload) async throws
    func deleteResponses(pushID: String, personIDs: [String]) async throws
    func loadFriendships() async throws -> [FriendshipRow]
    func incomingFriendRequestMutualCounts() async throws -> [IncomingFriendRequestMutualCountRow]
    func searchProfiles(query: String, limit: Int) async throws -> [SearchProfileRow]
    func discoverProfiles(limit: Int) async throws -> [SearchProfileRow]
    func setGlobalSharingDefaults(
        location: String,
        activity: String,
        availability: String
    ) async throws -> SharingPolicyRow
    func completeOnboarding() async throws -> ProfileRow
    func sendFriendRequest(targetUserID: String) async throws -> FriendshipRow
    func resolveFriendRequest(id: String, accept: Bool) async throws -> FriendshipRow
    func cancelFriendRequest(id: String) async throws
    func removeFriend(targetUserID: String) async throws
    func blockUser(targetUserID: String) async throws
    func unblockUser(targetUserID: String) async throws
    func listBlockedUsers() async throws -> [SearchProfileRow]
    func loadProfile(id: String) async throws -> ProfileRow
    func createGroup(name: String, imageAssetPath: String?, inviteeIDs: [String]) async throws -> GroupRow
    func incomingGroupInvites() async throws -> [GroupInviteRow]
    func resolveGroupInvite(membershipID: String, accept: Bool) async throws -> GroupMembershipRow
    func renameGroup(groupID: String, name: String) async throws -> GroupRow
    func setGroupImage(groupID: String, imagePath: String?) async throws -> GroupRow
    func inviteToGroup(groupID: String, inviteeIDs: [String]) async throws
    func cancelGroupInvite(membershipID: String) async throws
    func removeGroupMember(groupID: String, personID: String) async throws
    func leaveGroup(groupID: String) async throws
    func transferGroupOwnership(groupID: String, newOwnerID: String) async throws
    func deleteGroup(groupID: String) async throws
}

struct ProfileSettingsPayload: Encodable {
    let settings_activity_visibility: [String: Bool]
    let settings_map_preferences: [String: Bool]
    let settings_close_friends: [String: Bool]
}

struct PushInsertPayload: Encodable {
    let title: String
    let group_id: String?
    let creator_id: String
    let starts_at: String
    let has_explicit_time: Bool
    let is_approximate_time: Bool
    let expires_at: String
    let audience: String
    let note: String?
    let location_text: String?
}

struct PushUpdatePayload: Encodable {
    let title: String
    let group_id: String?
    let starts_at: String
    let expires_at: String
    let audience: String
    let note: String?
    let location_text: String?
    let updated_at: String

    private enum CodingKeys: String, CodingKey {
        case title, group_id, starts_at, expires_at, audience, note, location_text, updated_at
    }

    // Same issue as `PushResponsePayload` below: the synthesized `Encodable`
    // calls `encodeIfPresent` for these Optional fields, which *omits* the
    // key when nil instead of writing `null`. For an UPDATE, an omitted key
    // means "leave this column alone," not "clear it" — so editing a push to
    // drop its group (or clear its note/location) silently failed to persist
    // that clearing. Encoding explicitly always emits the key so nil reaches
    // Postgres as an actual `null`.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(group_id, forKey: .group_id)
        try container.encode(starts_at, forKey: .starts_at)
        try container.encode(expires_at, forKey: .expires_at)
        try container.encode(audience, forKey: .audience)
        try container.encode(note, forKey: .note)
        try container.encode(location_text, forKey: .location_text)
        try container.encode(updated_at, forKey: .updated_at)
    }
}

struct PushCancelPayload: Encodable {
    let cancelled_at: String
}

/// Shape for both a fresh RSVP row (`insertResponses`, response usually
/// `.pending`) and a self-write RSVP (`upsertResponse`, keyed by the
/// `(push_id, person_id)` unique constraint).
struct PushResponsePayload: Encodable {
    let push_id: String
    let person_id: String
    let response: String
    let responded_at: String?

    private enum CodingKeys: String, CodingKey {
        case push_id, person_id, response, responded_at
    }

    // `insertResponses` sends an array (creator's responded row alongside
    // invitees' nil-`responded_at` pending rows) in one request; PostgREST
    // requires every object in a bulk insert to have identical keys
    // (PGRST102). The default synthesized `Encodable` calls `encodeIfPresent`
    // for `responded_at`, which *omits* the key when nil instead of writing
    // `null` — fine for a lone object, but it desyncs the key set across a
    // batch. Encoding explicitly (`encode`, not `encodeIfPresent`) always
    // emits the key, as `null` when nil, keeping every row's keys identical.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(push_id, forKey: .push_id)
        try container.encode(person_id, forKey: .person_id)
        try container.encode(response, forKey: .response)
        try container.encode(responded_at, forKey: .responded_at)
    }
}

@MainActor
final class LiveDataStore {
    private let loader: LiveDataLoading
    private var profileRows: [ProfileRow]?
    private var groupRows: [GroupRow]?
    private var membershipRows: [GroupMembershipRow]?
    private var policyRows: [SharingPolicyRow]?
    private var pushRows: [PushRow]?
    private var responseRows: [PushResponseRow]?
    private var presenceRows: [CurrentPresenceRow]?
    private var friendshipRows: [FriendshipRow]?
    private var blockedRows: [SearchProfileRow]?
    private var profilesTask: Task<[ProfileRow], Error>?
    private var groupsTask: Task<[GroupRow], Error>?
    private var membershipsTask: Task<[GroupMembershipRow], Error>?
    private var policiesTask: Task<[SharingPolicyRow], Error>?
    private var pushesTask: Task<[PushRow], Error>?
    private var responsesTask: Task<[PushResponseRow], Error>?
    private var presenceTask: Task<[CurrentPresenceRow], Error>?
    private var friendshipsTask: Task<[FriendshipRow], Error>?
    private var blockedTask: Task<[SearchProfileRow], Error>?
    private let revisionSubject = CurrentValueSubject<Int, Never>(0)
    private var refreshTask: Task<Void, Error>?
    private var lastSuccessfulRefreshAt: Date?

    init(loader: LiveDataLoading) { self.loader = loader }

    var revision: Int { revisionSubject.value }

    func onChange(_ handler: @escaping (Int) -> Void) -> AnyCancellable {
        revisionSubject.dropFirst().sink(receiveValue: handler)
    }

    func warm() async throws {
        async let profiles = profiles()
        async let groups = groups()
        async let memberships = memberships()
        async let policies = policies()
        async let pushes = pushes()
        async let responses = pushResponses()
        async let presence = currentPresence()
        // Friendships + blocks gate Friends/Map/Plans derivation; warm with the
        // social graph so tab opens do not pay a network round-trip per load.
        async let friendships = friendships()
        async let blocked = blockedUserRows()
        _ = try await (
            profiles, groups, memberships, policies, pushes, responses, presence,
            friendships, blocked
        )
    }

    /// Clears session caches, re-warms, and publishes one revision on success.
    /// Concurrent callers await the same in-flight task. A new refresh started
    /// within `SessionRefreshConstants.minimumInterval` of a successful one is a no-op.
    /// Failed re-warms restore the prior snapshot and do not bump revision.
    func refresh() async throws {
        if let refreshTask {
            try await refreshTask.value
            return
        }
        if let lastSuccessfulRefreshAt,
           Date().timeIntervalSince(lastSuccessfulRefreshAt) < SessionRefreshConstants.minimumInterval {
            return
        }
        let task = Task { try await performRefresh() }
        refreshTask = task
        do {
            try await task.value
            refreshTask = nil
        } catch {
            refreshTask = nil
            throw error
        }
    }

    private func performRefresh() async throws {
        let snapshot = SessionCacheSnapshot(
            profileRows: profileRows,
            groupRows: groupRows,
            membershipRows: membershipRows,
            policyRows: policyRows,
            pushRows: pushRows,
            responseRows: responseRows,
            presenceRows: presenceRows,
            friendshipRows: friendshipRows,
            blockedRows: blockedRows
        )
        clearAllSessionCaches()
        do {
            try await warm()
            lastSuccessfulRefreshAt = Date()
            revisionSubject.value += 1
        } catch {
            restoreSessionCaches(from: snapshot)
            throw error
        }
    }

    private func clearAllSessionCaches() {
        profileRows = nil
        groupRows = nil
        membershipRows = nil
        policyRows = nil
        pushRows = nil
        responseRows = nil
        presenceRows = nil
        friendshipRows = nil
        blockedRows = nil
        profilesTask = nil
        groupsTask = nil
        membershipsTask = nil
        policiesTask = nil
        pushesTask = nil
        responsesTask = nil
        presenceTask = nil
        friendshipsTask = nil
        blockedTask = nil
    }

    private func restoreSessionCaches(from snapshot: SessionCacheSnapshot) {
        profileRows = snapshot.profileRows
        groupRows = snapshot.groupRows
        membershipRows = snapshot.membershipRows
        policyRows = snapshot.policyRows
        pushRows = snapshot.pushRows
        responseRows = snapshot.responseRows
        presenceRows = snapshot.presenceRows
        friendshipRows = snapshot.friendshipRows
        blockedRows = snapshot.blockedRows
    }

    private struct SessionCacheSnapshot {
        let profileRows: [ProfileRow]?
        let groupRows: [GroupRow]?
        let membershipRows: [GroupMembershipRow]?
        let policyRows: [SharingPolicyRow]?
        let pushRows: [PushRow]?
        let responseRows: [PushResponseRow]?
        let presenceRows: [CurrentPresenceRow]?
        let friendshipRows: [FriendshipRow]?
        let blockedRows: [SearchProfileRow]?
    }

    func profiles() async throws -> [ProfileRow] {
        if let profileRows { return profileRows }
        if let profilesTask { return try await profilesTask.value }
        let task = Task { try await loader.loadProfiles().uniqued(by: \.id) }
        profilesTask = task
        do {
            let rows = try await task.value
            profileRows = rows
            profilesTask = nil
            return profileRows ?? []
        } catch {
            profilesTask = nil
            throw error
        }
    }

    func profile(userID: String) async throws -> ProfileRow {
        guard let row = try await profiles().first(where: { $0.matches(id: userID) }) else {
            throw SupabaseRepositoryError.notFound
        }
        return row
    }

    func groups() async throws -> [GroupRow] {
        if let groupRows { return groupRows }
        if let groupsTask { return try await groupsTask.value }
        let task = Task { try await loader.loadGroups().uniqued(by: \.id) }
        groupsTask = task
        return try await finish(task, cache: { groupRows = $0 }, clear: { groupsTask = nil })
    }

    func memberships() async throws -> [GroupMembershipRow] {
        if let membershipRows { return membershipRows }
        if let membershipsTask { return try await membershipsTask.value }
        let task = Task { try await loader.loadMemberships().uniqued(by: \.id) }
        membershipsTask = task
        return try await finish(
            task, cache: { membershipRows = $0 }, clear: { membershipsTask = nil }
        )
    }

    // MARK: - Groups (writes)
    //
    // Like pushes: no long-lived cache for the write path itself, but the
    // read caches above (`groupRows`/`membershipRows`) go stale the moment a
    // group is created or an invite resolved, so both paths drop them via
    // `notifyGroupsChanged()` before bumping the revision.

    func createGroup(name: String, imageAssetPath: String?, inviteeIDs: [String]) async throws -> GroupRow {
        let row = try await loader.createGroup(
            name: name, imageAssetPath: imageAssetPath, inviteeIDs: inviteeIDs
        )
        notifyGroupsChanged()
        return row
    }

    func renameGroup(groupID: String, name: String) async throws {
        _ = try await loader.renameGroup(groupID: groupID, name: name)
        notifyGroupsChanged()
    }

    func setGroupImage(groupID: String, imagePath: String?) async throws {
        _ = try await loader.setGroupImage(groupID: groupID, imagePath: imagePath)
        notifyGroupsChanged()
    }

    func inviteToGroup(groupID: String, inviteeIDs: [String]) async throws {
        try await loader.inviteToGroup(groupID: groupID, inviteeIDs: inviteeIDs)
        notifyGroupsChanged()
    }

    func cancelGroupInvite(membershipID: String) async throws {
        try await loader.cancelGroupInvite(membershipID: membershipID)
        notifyGroupsChanged()
    }

    func removeGroupMember(groupID: String, personID: String) async throws {
        try await loader.removeGroupMember(groupID: groupID, personID: personID)
        notifyGroupsChanged()
    }

    func leaveGroup(groupID: String) async throws {
        try await loader.leaveGroup(groupID: groupID)
        notifyGroupsChanged()
    }

    func transferGroupOwnership(groupID: String, newOwnerID: String) async throws {
        try await loader.transferGroupOwnership(groupID: groupID, newOwnerID: newOwnerID)
        notifyGroupsChanged()
    }

    func deleteGroup(groupID: String) async throws {
        try await loader.deleteGroup(groupID: groupID)
        notifyGroupsChanged()
    }

    /// Current cached `image_asset_path` for a group, if the groups snapshot is warm.
    func cachedGroupImagePath(groupID: String) -> String? {
        groupRows?.first(where: {
            $0.id.caseInsensitiveCompare(groupID) == .orderedSame
        })?.image_asset_path
    }

    func incomingGroupInvites() async throws -> [GroupInviteRow] {
        try await loader.incomingGroupInvites()
    }

    func resolveGroupInvite(id: String, accept: Bool) async throws {
        _ = try await loader.resolveGroupInvite(membershipID: id, accept: accept)
        notifyGroupsChanged()
    }

    /// Drop the group/membership snapshot so the next read re-fetches, then
    /// bump the revision. Called after create (creator's list gains the new
    /// group) and after accept (invitee's list gains it on their next load).
    func notifyGroupsChanged() {
        groupRows = nil
        membershipRows = nil
        groupsTask = nil
        membershipsTask = nil
        revisionSubject.value += 1
    }

    func policies() async throws -> [SharingPolicyRow] {
        if let policyRows { return policyRows }
        if let policiesTask { return try await policiesTask.value }
        let task = Task { try await loader.loadPolicies().uniqued(by: \.id) }
        policiesTask = task
        return try await finish(task, cache: { policyRows = $0 }, clear: { policiesTask = nil })
    }

    func updateBasics(userID: String, displayName: String, handle: String) async throws {
        replace(try await loader.updateBasics(userID: userID, displayName: displayName, handle: handle))
    }

    func updatePrivacy(userID: String, payload: ProfileSettingsPayload) async throws {
        replace(try await loader.updatePrivacy(userID: userID, payload: payload))
    }

    /// Dual-write via `set_availability_choice`: canonical profile + presence mirror.
    /// One revision on success only; does not invent presence or flip is_published.
    func updateAvailability(userID: String, rawValue: String) async throws {
        let row = try await loader.updateAvailability(userID: userID, rawValue: rawValue)
        applyAvailabilityDualWrite(profileRow: row, rawValue: rawValue)
    }

    /// Sync read of profile availability for location draft mirroring (never invents).
    func cachedAvailability(userID: String) -> FriendAvailabilityState? {
        guard let row = profileRows?.first(where: {
            $0.id.caseInsensitiveCompare(userID) == .orderedSame
        }) else { return nil }
        return row.userProfile().chosenAvailability
    }

    /// Patch profile + existing presence availability after successful RPC — one bump.
    private func applyAvailabilityDualWrite(profileRow: ProfileRow, rawValue: String) {
        if var rows = profileRows,
           let index = rows.firstIndex(where: {
               $0.id.caseInsensitiveCompare(profileRow.id) == .orderedSame
           }) {
            rows[index] = profileRow
            profileRows = rows
        } else if profileRows != nil {
            profileRows?.append(profileRow)
        } else {
            // Snapshot not warm — still bump so listeners reload from network.
            revisionSubject.value += 1
            return
        }

        if var presence = presenceRows,
           let index = presence.firstIndex(where: {
               $0.user_id.caseInsensitiveCompare(profileRow.id) == .orderedSame
           }) {
            let old = presence[index]
            presence[index] = CurrentPresenceRow(
                user_id: old.user_id,
                availability: rawValue,
                is_published: old.is_published,
                activity_name: old.activity_name,
                activity_symbol: old.activity_symbol,
                place_id: old.place_id,
                status_note: old.status_note,
                latitude: old.latitude,
                longitude: old.longitude,
                vague_latitude: old.vague_latitude,
                vague_longitude: old.vague_longitude,
                confidence: old.confidence,
                observed_at: old.observed_at,
                updated_at: old.updated_at,
                expires_at: old.expires_at,
                source: old.source
            )
            presenceRows = presence
        }
        revisionSubject.value += 1
    }

    func updateImagePath(userID: String, imageAssetPath: String?) async throws {
        replace(try await loader.updateImagePath(userID: userID, imageAssetPath: imageAssetPath))
    }

    /// Current cached path for the user, if the profiles snapshot is warm.
    func cachedImagePath(userID: String) -> String? {
        profileRows?.first(where: { $0.id.lowercased() == userID.lowercased() })?.image_asset_path
    }

    private func finish<Value>(
        _ task: Task<[Value], Error>, cache: ([Value]) -> Void, clear: () -> Void
    ) async throws -> [Value] {
        defer { clear() }
        let rows = try await task.value
        cache(rows)
        return rows
    }

    private func replace(_ row: ProfileRow) {
        guard var rows = profileRows, let index = rows.firstIndex(where: { $0.id == row.id }) else { return }
        rows[index] = row
        profileRows = rows
        revisionSubject.value += 1
    }

    // MARK: - Pushes
    //
    // Session-cached like the social graph so the Pushes tab paints from the
    // bootstrap snapshot instead of waiting on a network round-trip. Day-1
    // still has no realtime: local writes invalidate via `notifyPushesChanged()`
    // (one bump after multi-step create/edit) so the next read re-fetches.
    // Remote friend edits surface on the next invalidate/re-warm, not every
    // tab open — matching how profile/group reads already behave.

    func pushes() async throws -> [PushRow] {
        if let pushRows { return pushRows }
        if let pushesTask { return try await pushesTask.value }
        let task = Task { try await loader.loadPushes().uniqued(by: \.id) }
        pushesTask = task
        return try await finish(task, cache: { pushRows = $0 }, clear: { pushesTask = nil })
    }

    func pushResponses() async throws -> [PushResponseRow] {
        if let responseRows { return responseRows }
        if let responsesTask { return try await responsesTask.value }
        let task = Task { try await loader.loadResponses().uniqued(by: \.id) }
        responsesTask = task
        return try await finish(
            task, cache: { responseRows = $0 }, clear: { responsesTask = nil }
        )
    }

    func insertPush(_ payload: PushInsertPayload) async throws -> PushRow {
        try await loader.insertPush(payload)
    }

    func updatePush(id: String, payload: PushUpdatePayload) async throws -> PushRow {
        try await loader.updatePush(id: id, payload: payload)
    }

    func cancelPush(id: String, payload: PushCancelPayload) async throws -> PushRow {
        try await loader.cancelPush(id: id, payload: payload)
    }

    func deletePush(id: String) async throws {
        try await loader.deletePush(id: id)
    }

    func insertResponses(_ payloads: [PushResponsePayload]) async throws {
        guard !payloads.isEmpty else { return }
        try await loader.insertResponses(payloads)
    }

    func upsertResponse(_ payload: PushResponsePayload) async throws {
        try await loader.upsertResponse(payload)
    }

    func deleteResponses(pushID: String, personIDs: [String]) async throws {
        guard !personIDs.isEmpty else { return }
        try await loader.deleteResponses(pushID: pushID, personIDs: personIDs)
    }

    /// Drop the push snapshot so the following ViewModel reload re-fetches,
    /// then publish one revision after every step of a write has succeeded.
    func notifyPushesChanged() {
        pushRows = nil
        responseRows = nil
        pushesTask = nil
        responsesTask = nil
        revisionSubject.value += 1
    }

    // MARK: - Presence
    //
    // Session-cached like the social graph / pushes. Warm + refresh load
    // `current_presence`; self writes replace the own row (write-through) and
    // bump one revision. Realtime / external invalidation uses
    // `notifyPresenceChanged()` which clears the cache.

    func currentPresence() async throws -> [CurrentPresenceRow] {
        if let presenceRows { return presenceRows }
        if let presenceTask { return try await presenceTask.value }
        let task = Task {
            try await loader.loadPresence().uniqued(by: \.user_id)
        }
        presenceTask = task
        return try await finish(
            task, cache: { presenceRows = $0 }, clear: { presenceTask = nil }
        )
    }

    /// Network upsert then replace own cached row — one revision on success only.
    @discardableResult
    func upsertOwnPresence(
        userID: String,
        draft: PresenceStatusDraft,
        now: Date = Date()
    ) async throws -> CurrentPresenceRow {
        let payload = CurrentPresenceWriteMapping.payload(
            userID: userID, draft: draft, now: now
        )
        let row = try await loader.upsertCurrentPresence(payload)
        applyPresenceWriteThrough(row)
        return row
    }

    /// RPC unpublish then clear friend-visible fields on the own cached row.
    func unpublishOwnPresence(userID: String, now: Date = Date()) async throws {
        try await loader.unpublishCurrentPresence()
        applyPresenceUnpublish(userID: userID, now: now)
    }

    /// Replace or append the returned presence row in the session cache.
    func applyPresenceWriteThrough(_ row: CurrentPresenceRow) {
        if var rows = presenceRows {
            if let index = rows.firstIndex(where: {
                $0.user_id.caseInsensitiveCompare(row.user_id) == .orderedSame
            }) {
                rows[index] = row
            } else {
                rows.append(row)
            }
            presenceRows = rows
        }
        // If the snapshot was never warm, leave it nil so the next read re-fetches
        // friends + self together — still bump so listeners reload.
        presenceTask = nil
        revisionSubject.value += 1
    }

    /// Patch own row to unpublished after a successful unpublish RPC.
    func applyPresenceUnpublish(userID: String, now: Date = Date()) {
        if var rows = presenceRows {
            let existing = rows.first {
                $0.user_id.caseInsensitiveCompare(userID) == .orderedSame
            }
            let updated = CurrentPresenceWriteMapping.unpublishedRow(
                from: existing, userID: userID, now: now
            )
            if let index = rows.firstIndex(where: {
                $0.user_id.caseInsensitiveCompare(userID) == .orderedSame
            }) {
                rows[index] = updated
            } else {
                rows.append(updated)
            }
            presenceRows = rows
        }
        presenceTask = nil
        revisionSubject.value += 1
    }

    /// Drop the presence snapshot and publish one revision (Realtime / external).
    func notifyPresenceChanged() {
        presenceRows = nil
        presenceTask = nil
        revisionSubject.value += 1
    }

    // MARK: - Presence Realtime (Issue #84)
    //
    // Remote patches return a material-change flag; the bridge owns debounced
    // revision publishing. Self write-through remains on the methods above.

    /// Upsert a remote presence row when newer than the cached row.
    /// - Returns: `true` when cache content should trigger a revision.
    @discardableResult
    func applyRemotePresenceRow(_ row: CurrentPresenceRow) -> Bool {
        guard let rows = presenceRows else {
            // Never warm: force listeners to reload so the next read refetches.
            presenceTask = nil
            return true
        }
        let remoteUpdated = PushDateFormatting.parse(row.updated_at)
        if let index = rows.firstIndex(where: {
            $0.user_id.caseInsensitiveCompare(row.user_id) == .orderedSame
        }) {
            let existing = rows[index]
            if isRemotePresenceStale(remote: row, remoteUpdated: remoteUpdated, existing: existing) {
                return false
            }
            if existing == row { return false }
            var updated = rows
            updated[index] = row
            presenceRows = updated
            presenceTask = nil
            return true
        }
        var updated = rows
        updated.append(row)
        presenceRows = updated
        presenceTask = nil
        return true
    }

    /// Remove a remote user's presence row from the warm cache.
    @discardableResult
    func removeRemotePresence(userID: String) -> Bool {
        guard var rows = presenceRows else { return false }
        let before = rows.count
        rows.removeAll {
            $0.user_id.caseInsensitiveCompare(userID) == .orderedSame
        }
        guard rows.count != before else { return false }
        presenceRows = rows
        presenceTask = nil
        return true
    }

    /// Canonical presence re-read. Replaces the warm snapshot.
    /// - Returns: `true` when the snapshot differs from what was cached.
    @discardableResult
    func reconcilePresence() async throws -> Bool {
        let previous = presenceRows
        let rows = try await loader.loadPresence().uniqued(by: \.user_id)
        presenceRows = rows
        presenceTask = nil
        guard let previous else { return true }
        return previous != rows
    }

    /// Publish one store revision after a material remote presence batch.
    func publishPresenceRevision() {
        revisionSubject.value += 1
    }

    private func isRemotePresenceStale(
        remote: CurrentPresenceRow,
        remoteUpdated: Date?,
        existing: CurrentPresenceRow
    ) -> Bool {
        guard let remoteUpdated else { return false }
        guard let existingUpdated = PushDateFormatting.parse(existing.updated_at) else {
            return false
        }
        return remoteUpdated < existingUpdated
    }

    // MARK: - Friendships
    //
    // Session-cached like the rest of the social graph so Map/Friends/Plans can
    // paint from the bootstrap snapshot. Mutations invalidate friendships +
    // blocks (and often profiles) via `notifyFriendshipsChanged()`.

    func friendships() async throws -> [FriendshipRow] {
        if let friendshipRows { return friendshipRows }
        if let friendshipsTask { return try await friendshipsTask.value }
        let task = Task { try await loader.loadFriendships().uniqued(by: \.id) }
        friendshipsTask = task
        return try await finish(
            task, cache: { friendshipRows = $0 }, clear: { friendshipsTask = nil }
        )
    }

    /// Not session-cached: this aggregate is inbox-specific and should reflect
    /// request cancellation or friendship changes whenever Alerts reloads.
    func incomingFriendRequestMutualCounts() async throws -> [IncomingFriendRequestMutualCountRow] {
        try await loader.incomingFriendRequestMutualCounts()
    }

    func searchProfiles(query: String, limit: Int = 20) async throws -> [SearchProfileRow] {
        try await loader.searchProfiles(query: query, limit: limit)
    }

    func discoverProfiles(limit: Int = 20) async throws -> [SearchProfileRow] {
        try await loader.discoverProfiles(limit: limit)
    }

    func setGlobalSharingDefaults(
        location: String,
        activity: String,
        availability: String
    ) async throws {
        let row = try await loader.setGlobalSharingDefaults(
            location: location,
            activity: activity,
            availability: availability
        )
        // Refresh policy cache so map builders see the new defaults.
        if var cached = policyRows {
            cached.removeAll {
                $0.owner_person_id.caseInsensitiveCompare(row.owner_person_id) == .orderedSame
                    && $0.audience_type == "global_default"
            }
            cached.append(row)
            policyRows = cached
        } else {
            policyRows = nil
            policiesTask = nil
        }
        revisionSubject.value += 1
    }

    func completeOnboarding(userID: String) async throws {
        let row = try await loader.completeOnboarding()
        // Write-through current-user profile cache.
        if var cached = profileRows,
           let index = cached.firstIndex(where: {
               $0.id.caseInsensitiveCompare(userID) == .orderedSame
           }) {
            cached[index] = row
            profileRows = cached
        } else {
            profileRows = nil
            profilesTask = nil
        }
        revisionSubject.value += 1
    }

    @discardableResult
    func sendFriendRequest(targetUserID: String) async throws -> FriendRequest.ID {
        let row = try await loader.sendFriendRequest(targetUserID: targetUserID)
        notifyFriendshipsChanged()
        return row.id
    }

    func resolveFriendRequest(id: String, accept: Bool) async throws {
        _ = try await loader.resolveFriendRequest(id: id, accept: accept)
        // Accept expands profile visibility; drop the warm cache so friends() refreshes.
        profileRows = nil
        profilesTask = nil
        notifyFriendshipsChanged()
    }

    func cancelFriendRequest(id: String) async throws {
        try await loader.cancelFriendRequest(id: id)
        notifyFriendshipsChanged()
    }

    func removeFriend(targetUserID: String) async throws {
        try await loader.removeFriend(targetUserID: targetUserID)
        // Removal narrows profile visibility; drop the warm cache so friends() refreshes.
        profileRows = nil
        profilesTask = nil
        notifyFriendshipsChanged()
    }

    func blockUser(targetUserID: String) async throws {
        try await loader.blockUser(targetUserID: targetUserID)
        // Block tears down friendship and hides the peer; drop warm profiles.
        profileRows = nil
        profilesTask = nil
        notifyFriendshipsChanged()
    }

    func unblockUser(targetUserID: String) async throws {
        try await loader.unblockUser(targetUserID: targetUserID)
        // Friendship is not restored, but search/list visibility can change.
        profileRows = nil
        profilesTask = nil
        notifyFriendshipsChanged()
    }

    func listBlockedUsers() async throws -> [BlockedPerson] {
        try await blockedUserRows().map { row in
            BlockedPerson(
                id: row.id,
                firstName: row.first_name,
                handle: row.handle,
                imageAssetPath: row.image_asset_path
            )
        }
    }

    private func blockedUserRows() async throws -> [SearchProfileRow] {
        if let blockedRows { return blockedRows }
        if let blockedTask { return try await blockedTask.value }
        let task = Task { try await loader.listBlockedUsers().uniqued(by: \.id) }
        blockedTask = task
        return try await finish(
            task, cache: { blockedRows = $0 }, clear: { blockedTask = nil }
        )
    }

    /// Fetches a single profile when it may not yet be in the warm snapshot
    /// (e.g. a pending requester who isn't a friend yet).
    func profileForFriendship(userID: String) async throws -> ProfileRow {
        if let cached = try? await profiles().first(where: { $0.matches(id: userID) }) {
            return cached
        }
        return try await loader.loadProfile(id: userID)
    }

    /// Drop friendship/block snapshots so the next read re-fetches, then bump.
    func notifyFriendshipsChanged() {
        friendshipRows = nil
        friendshipsTask = nil
        blockedRows = nil
        blockedTask = nil
        revisionSubject.value += 1
    }
}

private extension Array {
    func uniqued<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}

private extension ProfileRow {
    func matches(id otherID: String) -> Bool {
        id.caseInsensitiveCompare(otherID) == .orderedSame
    }
}
