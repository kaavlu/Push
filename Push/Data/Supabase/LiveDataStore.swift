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
    func loadPushes() async throws -> [PushRow]
    func loadResponses() async throws -> [PushResponseRow]
    func insertPush(_ payload: PushInsertPayload) async throws -> PushRow
    func updatePush(id: String, payload: PushUpdatePayload) async throws -> PushRow
    func cancelPush(id: String, payload: PushCancelPayload) async throws -> PushRow
    func deletePush(id: String) async throws
    func insertResponses(_ payloads: [PushResponsePayload]) async throws
    func upsertResponse(_ payload: PushResponsePayload) async throws
    func deleteResponses(pushID: String, personIDs: [String]) async throws
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
    private var profilesTask: Task<[ProfileRow], Error>?
    private var groupsTask: Task<[GroupRow], Error>?
    private var membershipsTask: Task<[GroupMembershipRow], Error>?
    private var policiesTask: Task<[SharingPolicyRow], Error>?
    private let revisionSubject = CurrentValueSubject<Int, Never>(0)

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
        _ = try await (profiles, groups, memberships, policies)
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

    func updateAvailability(userID: String, rawValue: String) async throws {
        replace(try await loader.updateAvailability(userID: userID, rawValue: rawValue))
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
    // Unlike profiles/groups/memberships/policies, pushes have no session
    // cache: every read re-fetches from Supabase (Day-1 has no realtime
    // subscription, so this is how friends' new/edited pushes show up when
    // the Pushes tab reloads). Mutations call the loader directly and the
    // repository calls `notifyPushesChanged()` once per logical write —
    // which may span several loader calls (e.g. insert push + seed
    // responses) — so ViewModels reload only after the write is complete.

    func pushes() async throws -> [PushRow] {
        try await loader.loadPushes()
    }

    func pushResponses() async throws -> [PushResponseRow] {
        try await loader.loadResponses()
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

    /// Pushes have no cached rows to `replace(_:)`, so callers bump
    /// explicitly, once, after every step of a write succeeds.
    func notifyPushesChanged() {
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

@MainActor
final class SupabaseLiveDataLoader: LiveDataLoading {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func loadProfiles() async throws -> [ProfileRow] {
        try await client.from("profiles").select().execute().value
    }

    func loadGroups() async throws -> [GroupRow] {
        try await client.from("groups").select().execute().value
    }

    func loadMemberships() async throws -> [GroupMembershipRow] {
        try await client.from("group_memberships").select().execute().value
    }

    func loadPolicies() async throws -> [SharingPolicyRow] {
        try await client.from("sharing_policies").select().execute().value
    }

    func updateBasics(userID: String, displayName: String, handle: String) async throws -> ProfileRow {
        try await client.from("profiles")
            .update(ProfileBasicsPayload(first_name: displayName, handle: handle))
            .eq("id", value: userID).select().single().execute().value
    }

    func updatePrivacy(userID: String, payload: ProfileSettingsPayload) async throws -> ProfileRow {
        try await client.from("profiles").update(payload)
            .eq("id", value: userID).select().single().execute().value
    }

    func updateAvailability(userID: String, rawValue: String) async throws -> ProfileRow {
        try await client.from("profiles").update(AvailabilityPayload(availability_choice: rawValue))
            .eq("id", value: userID).select().single().execute().value
    }

    func loadPushes() async throws -> [PushRow] {
        try await client.from("pushes").select().execute().value
    }

    func loadResponses() async throws -> [PushResponseRow] {
        try await client.from("push_responses").select().execute().value
    }

    func insertPush(_ payload: PushInsertPayload) async throws -> PushRow {
        try await client.from("pushes").insert(payload).select().single().execute().value
    }

    func updatePush(id: String, payload: PushUpdatePayload) async throws -> PushRow {
        try await client.from("pushes").update(payload)
            .eq("id", value: id).select().single().execute().value
    }

    func cancelPush(id: String, payload: PushCancelPayload) async throws -> PushRow {
        try await client.from("pushes").update(payload)
            .eq("id", value: id).select().single().execute().value
    }

    func deletePush(id: String) async throws {
        try await client.from("pushes").delete().eq("id", value: id).execute()
    }

    func insertResponses(_ payloads: [PushResponsePayload]) async throws {
        try await client.from("push_responses").insert(payloads).execute()
    }

    func upsertResponse(_ payload: PushResponsePayload) async throws {
        try await client.from("push_responses")
            .upsert(payload, onConflict: "push_id,person_id")
            .execute()
    }

    func deleteResponses(pushID: String, personIDs: [String]) async throws {
        try await client.from("push_responses").delete()
            .eq("push_id", value: pushID)
            .in("person_id", values: personIDs)
            .execute()
    }
}

private struct ProfileBasicsPayload: Encodable {
    let first_name: String
    let handle: String
}

private struct AvailabilityPayload: Encodable {
    let availability_choice: String
}
