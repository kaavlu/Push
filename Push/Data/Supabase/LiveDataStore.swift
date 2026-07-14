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
}

struct ProfileSettingsPayload: Encodable {
    let settings_activity_visibility: [String: Bool]
    let settings_map_preferences: [String: Bool]
    let settings_close_friends: [String: Bool]
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
}

private struct ProfileBasicsPayload: Encodable {
    let first_name: String
    let handle: String
}

private struct AvailabilityPayload: Encodable {
    let availability_choice: String
}
