//
//  SupabaseLiveDataLoader.swift
//  Push
//
//  PostgREST I/O behind `LiveDataStore`. Views and ViewModels never import this.
//
//  Every method routes through `PushLog.logged` so a backend failure gets
//  one consistent, PII-free log line (see PushLog for the redaction rule)
//  before the original error propagates unchanged.
//

import Foundation
import Supabase

@MainActor
final class SupabaseLiveDataLoader: LiveDataLoading {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func loadProfiles() async throws -> [ProfileRow] {
        try await PushLog.logged("loadProfiles") {
            try await client.from("profiles").select().execute().value
        }
    }

    func loadGroups() async throws -> [GroupRow] {
        try await PushLog.logged("loadGroups") {
            try await client.from("groups").select().execute().value
        }
    }

    func loadMemberships() async throws -> [GroupMembershipRow] {
        try await PushLog.logged("loadMemberships") {
            try await client.from("group_memberships").select().execute().value
        }
    }

    func loadPolicies() async throws -> [SharingPolicyRow] {
        try await PushLog.logged("loadPolicies") {
            try await client.from("sharing_policies").select().execute().value
        }
    }

    func updateBasics(userID: String, displayName: String, handle: String) async throws -> ProfileRow {
        try await PushLog.logged("updateBasics") {
            try await client.from("profiles")
                .update(ProfileBasicsPayload(first_name: displayName, handle: handle))
                .eq("id", value: userID).select().single().execute().value
        }
    }

    func updatePrivacy(userID: String, payload: ProfileSettingsPayload) async throws -> ProfileRow {
        try await PushLog.logged("updatePrivacy") {
            try await client.from("profiles").update(payload)
                .eq("id", value: userID).select().single().execute().value
        }
    }

    func updateAvailability(userID: String, rawValue: String) async throws -> ProfileRow {
        try await PushLog.logged("updateAvailability") {
            try await client.from("profiles").update(AvailabilityPayload(availability_choice: rawValue))
                .eq("id", value: userID).select().single().execute().value
        }
    }

    func updateImagePath(userID: String, imageAssetPath: String?) async throws -> ProfileRow {
        try await PushLog.logged("updateImagePath") {
            try await client.from("profiles")
                .update(ProfileImagePayload(image_asset_path: imageAssetPath))
                .eq("id", value: userID).select().single().execute().value
        }
    }

    func loadPushes() async throws -> [PushRow] {
        try await PushLog.logged("loadPushes") {
            try await client.from("pushes").select().execute().value
        }
    }

    func loadResponses() async throws -> [PushResponseRow] {
        try await PushLog.logged("loadResponses") {
            try await client.from("push_responses").select().execute().value
        }
    }

    func insertPush(_ payload: PushInsertPayload) async throws -> PushRow {
        try await PushLog.logged("insertPush") {
            try await client.from("pushes").insert(payload).select().single().execute().value
        }
    }

    func updatePush(id: String, payload: PushUpdatePayload) async throws -> PushRow {
        try await PushLog.logged("updatePush") {
            try await client.from("pushes").update(payload)
                .eq("id", value: id).select().single().execute().value
        }
    }

    func cancelPush(id: String, payload: PushCancelPayload) async throws -> PushRow {
        try await PushLog.logged("cancelPush") {
            try await client.from("pushes").update(payload)
                .eq("id", value: id).select().single().execute().value
        }
    }

    func deletePush(id: String) async throws {
        try await PushLog.logged("deletePush") {
            try await client.from("pushes").delete().eq("id", value: id).execute()
        }
    }

    func insertResponses(_ payloads: [PushResponsePayload]) async throws {
        try await PushLog.logged("insertResponses") {
            try await client.from("push_responses").insert(payloads).execute()
        }
    }

    func upsertResponse(_ payload: PushResponsePayload) async throws {
        try await PushLog.logged("upsertResponse") {
            try await client.from("push_responses")
                .upsert(payload, onConflict: "push_id,person_id")
                .execute()
        }
    }

    func deleteResponses(pushID: String, personIDs: [String]) async throws {
        try await PushLog.logged("deleteResponses") {
            try await client.from("push_responses").delete()
                .eq("push_id", value: pushID)
                .in("person_id", values: personIDs)
                .execute()
        }
    }

    func loadFriendships() async throws -> [FriendshipRow] {
        try await PushLog.logged("loadFriendships") {
            try await client.from("friendships").select().execute().value
        }
    }

    func searchProfiles(query: String, limit: Int) async throws -> [SearchProfileRow] {
        try await PushLog.logged("searchProfiles") {
            try await client
                .rpc(
                    "search_profiles",
                    params: SearchProfilesParams(search_query: query, result_limit: limit)
                )
                .execute()
                .value
        }
    }

    func sendFriendRequest(targetUserID: String) async throws -> FriendshipRow {
        try await PushLog.logged("sendFriendRequest") {
            try await client
                .rpc("send_friend_request", params: SendFriendRequestParams(target_user_id: targetUserID))
                .execute()
                .value
        }
    }

    func resolveFriendRequest(id: String, accept: Bool) async throws -> FriendshipRow {
        try await PushLog.logged("resolveFriendRequest") {
            try await client
                .rpc(
                    "resolve_friend_request",
                    params: ResolveFriendRequestParams(request_id: id, accept: accept)
                )
                .execute()
                .value
        }
    }

    func cancelFriendRequest(id: String) async throws {
        try await PushLog.logged("cancelFriendRequest") {
            try await client
                .rpc("cancel_friend_request", params: CancelFriendRequestParams(request_id: id))
                .execute()
        }
    }

    func removeFriend(targetUserID: String) async throws {
        try await PushLog.logged("removeFriend") {
            try await client
                .rpc("remove_friend", params: RemoveFriendParams(other_user_id: targetUserID))
                .execute()
        }
    }

    func loadProfile(id: String) async throws -> ProfileRow {
        try await PushLog.logged("loadProfile") {
            try await client.from("profiles")
                .select()
                .eq("id", value: id)
                .single()
                .execute()
                .value
        }
    }

    func createGroup(name: String, imageAssetPath: String?, inviteeIDs: [String]) async throws -> GroupRow {
        try await PushLog.logged("createGroup") {
            try await client
                .rpc(
                    "create_group",
                    params: CreateGroupParams(
                        group_name: name, image_path: imageAssetPath, invitee_ids: inviteeIDs
                    )
                )
                .execute()
                .value
        }
    }

    func incomingGroupInvites() async throws -> [GroupInviteRow] {
        try await PushLog.logged("incomingGroupInvites") {
            try await client.rpc("incoming_group_invites").execute().value
        }
    }

    func resolveGroupInvite(membershipID: String, accept: Bool) async throws -> GroupMembershipRow {
        try await PushLog.logged("resolveGroupInvite") {
            try await client
                .rpc(
                    "resolve_group_invite",
                    params: ResolveGroupInviteParams(membership_id: membershipID, accept: accept)
                )
                .execute()
                .value
        }
    }
}

private struct SearchProfilesParams: Encodable {
    let search_query: String
    let result_limit: Int
}

private struct SendFriendRequestParams: Encodable {
    let target_user_id: String
}

private struct ResolveFriendRequestParams: Encodable {
    let request_id: String
    let accept: Bool
}

private struct CancelFriendRequestParams: Encodable {
    let request_id: String
}

private struct RemoveFriendParams: Encodable {
    let other_user_id: String
}

private struct CreateGroupParams: Encodable {
    let group_name: String
    let image_path: String?
    let invitee_ids: [String]
}

private struct ResolveGroupInviteParams: Encodable {
    let membership_id: String
    let accept: Bool
}

private struct ProfileBasicsPayload: Encodable {
    let first_name: String
    let handle: String
}

private struct AvailabilityPayload: Encodable {
    let availability_choice: String
}

/// Explicit null encoding so remove-photo clears the column (default Optional
/// synthesis uses encodeIfPresent and would omit the key entirely).
private struct ProfileImagePayload: Encodable {
    let image_asset_path: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(image_asset_path, forKey: .image_asset_path)
    }

    private enum CodingKeys: String, CodingKey {
        case image_asset_path
    }
}
