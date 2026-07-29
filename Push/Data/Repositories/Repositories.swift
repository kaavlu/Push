//
//  Repositories.swift
//  Push
//
//  The seam between UI and data. All methods are async throws even though
//  the local implementations never fail — a Supabase implementation of
//  these protocols is a drop-in swap; view models and views stay untouched.
//

import Foundation

protocol FriendRepository {
    /// All friends in seed order, excluding the current user.
    func friends() async throws -> [Person]
    func currentUser() async throws -> Person
    /// Canonical internal presence — consumed by builders only, never by UI.
    func presenceStatuses() async throws -> [PresenceStatus]
    /// Writes the user's chosen availability to PresenceStatus and UserProfile,
    /// then bumps the store revision so view models reload.
    func setCurrentUserAvailability(_ availability: FriendAvailabilityState) async throws
    /// Discover people by display name and/or handle. Never returns the current user.
    func searchPeople(query: String) async throws -> [PersonSearchResult]
    /// First-run suggestions: people on Push who are not yet accepted friends.
    func discoverPeople(limit: Int) async throws -> [PersonSearchResult]
    /// Creates (or re-opens) a pending outgoing request.
    /// Returns the active request id (existing or newly created).
    @discardableResult
    func sendFriendRequest(to personID: Person.ID) async throws -> FriendRequest.ID
    /// Cancels an outgoing pending request the current user started.
    /// No-op / throws when the id is missing, not pending, or not owned by the caller.
    func cancelFriendRequest(id: FriendRequest.ID) async throws
    /// Hard-deletes the relationship with `personID` (any status), then bumps the
    /// store revision so view models reload. No-op if no row exists for the pair.
    func removeFriend(_ personID: Person.ID) async throws
    /// Blocks `personID`: removes friendship + pending requests between the pair,
    /// and hides them from search / alerts. Soft-hide for groups/pushes history.
    func blockUser(_ personID: Person.ID) async throws
    /// Removes an outbound block. Does **not** restore friendship.
    func unblockUser(_ personID: Person.ID) async throws
    /// People the current user has blocked, for settings UI.
    func blockedUsers() async throws -> [BlockedPerson]
}

/// Errors from group lifecycle mutations (create, rename, photo, invite, leave, etc.).
/// Maps to 0015 RPC exception strings for mock parity with live.
enum GroupRepositoryError: Error, Equatable {
    case notAuthenticated
    case notOwner
    case notMember
    case invalidName
    case invalidTarget
    case transferRequired
    case notPending
}

protocol GroupRepository {
    func groups() async throws -> [FriendGroup]
    func memberships() async throws -> [GroupMembership]
    /// Creates a group, adds the caller as its accepted owner, and creates
    /// pending (`invited`) memberships for each invitee — they become members
    /// only after accepting via `AlertRepository.acceptGroupInvite`.
    func createGroup(name: String, imageAssetPath: String?, inviteeIDs: [Person.ID]) async throws -> FriendGroup.ID
    func renameGroup(groupID: FriendGroup.ID, name: String) async throws
    func updateGroupPhoto(groupID: FriendGroup.ID, jpegData: Data) async throws
    func removeGroupPhoto(groupID: FriendGroup.ID) async throws
    func inviteToGroup(groupID: FriendGroup.ID, inviteeIDs: [Person.ID]) async throws
    func cancelGroupInvite(membershipID: GroupMembership.ID) async throws
    func removeMember(groupID: FriendGroup.ID, personID: Person.ID) async throws
    func leaveGroup(groupID: FriendGroup.ID) async throws
    func transferOwnership(groupID: FriendGroup.ID, newOwnerID: Person.ID) async throws
    func deleteGroup(groupID: FriendGroup.ID) async throws
}

/// Start Push flow output. `recipientIDs` are the flow's tokens
/// ("group_<id>" / "friend_<id>").
struct PushDraft {
    let title: String
    let recipientIDs: Set<String>
    let startsAt: Date
    let locationText: String
    let notes: String
    let creatorID: Person.ID
}

protocol PushRepository {
    /// Non-cancelled, not-yet-expired plans (time-derived active window).
    func activePlans() async throws -> [PushPlan]
    /// Completed non-cancelled plans whose `startsAt` falls in the given month.
    func historicalPlans(forMonthContaining date: Date) async throws -> [PushPlan]
    func responses() async throws -> [PushResponse]
    func setCurrentUserResponse(planID: PushPlan.ID, response: PushResponse.Response) async throws
    func pastHangouts(forMonthContaining date: Date) async throws -> [PastHangout]
    func allPlaces() async throws -> [Place]
    func createPush(_ draft: PushDraft) async throws -> PushPlan.ID
    func updatePush(planID: PushPlan.ID, with draft: PushDraft) async throws
    /// Soft-cancels an owned push (sets `cancelledAt`); no-op if `planID` isn't found.
    func cancelPush(planID: PushPlan.ID) async throws
    /// Hard-deletes an owned push (and its responses); no-op if `planID` isn't found.
    func deletePush(planID: PushPlan.ID) async throws
}

protocol ProfileRepository {
    func userProfile() async throws -> UserProfile
    /// Persists the display name (mapped to Person.firstName) and handle.
    func updateBasics(displayName: String, handle: String) async throws
    /// Persists the three privacy toggle arrays to the shared store.
    func updatePrivacy(
        activityVisibility: [ProfileToggleItem],
        mapPreferences: [ProfileToggleItem],
        closeFriends: [ProfileToggleItem]
    ) async throws
    /// Uploads a processed JPEG and points `Person.imageAssetPath` at it.
    /// Callers must resize/compress first via `ProfilePhotoProcessor`.
    func updateProfilePhoto(jpegData: Data) async throws
    /// Clears the profile photo path and removes the stored image when possible.
    func removeProfilePhoto() async throws
    /// New live accounts start incomplete; mock is always complete.
    func needsPostAuthOnboarding() async throws -> Bool
    /// Marks first-run setup finished (idempotent).
    func completeOnboarding() async throws
}

protocol SharingRepository {
    func allPolicies() async throws -> [SharingPolicy]
    /// Upserts the caller's global_default sharing policy (R3).
    func setGlobalDefaults(
        location: SharingPolicy.LocationVisibility,
        activity: SharingPolicy.DetailVisibility,
        availability: SharingPolicy.AvailabilityVisibility
    ) async throws
}

/// Activity timeline (Feed › Now) — deferred and empty in MVP. Moments live
/// behind `MomentRepository`; the two never share a type.
protocol FeedRepository {
    func events() async throws -> [FeedEvent]
}

/// Errors from Moment reads/mutations. Cases mirror the 0023 RPC exception
/// strings so mock and live surface the same failures to view models.
enum MomentRepositoryError: Error, Equatable {
    case notAuthenticated
    case notFound
    case notAllowed
    case mediaRequired
    case mediaLimitExceeded
    case invalidTag
    case invalidPush
    case momentExistsForPush
    case cannotRemoveCreator
    /// Reorder set mismatch — someone else changed the album first.
    case conflict
}

/// Moments (Feed › Pushes). Reads are viewer-scoped: media and counts arrive
/// already block-filtered, and every row carries its capability projection.
protocol MomentRepository {
    /// Newest activity first, keyset-paginated on `(lastActivityAt, id)`.
    /// `groupID` filters to Moments with a tagged member the viewer shares
    /// that group with; nil means no group predicate.
    func feedPage(
        cursor: MomentFeedCursor?, limit: Int, groupID: FriendGroup.ID?
    ) async throws -> MomentFeedPage
    /// Hub list: Moments the viewer created, is tagged in, or contributed to.
    func hubMoments() async throws -> [MomentSummary]
    func moment(id: Moment.ID) async throws -> MomentDetail
    /// Publish. Requires ≥1 media; the creator is tagged automatically.
    func createMoment(_ draft: MomentDraft) async throws -> Moment.ID
    /// Add yours. Appends at the end and bumps activity; items that fit the
    /// cap stay committed if a later one is rejected.
    func appendMedia(momentID: Moment.ID, items: [MomentMediaDraft]) async throws
    func updateMetadata(momentID: Moment.ID, title: String, locationText: String) async throws
    func addTags(momentID: Moment.ID, personIDs: [Person.ID]) async throws
    /// Removing yourself is the "hide attendance" path; the creator can never
    /// be removed. Uploaded media is kept either way.
    func removeTag(momentID: Moment.ID, personID: Person.ID) async throws
    func reorderMedia(momentID: Moment.ID, orderedMediaIDs: [MomentMedia.ID]) async throws
    /// Soft-deletes one item; deleting the last active item soft-deletes the Moment.
    func softDeleteMedia(mediaID: MomentMedia.ID) async throws
    func softDeleteMoment(momentID: Moment.ID) async throws
}

protocol AlertRepository {
    func incomingFriendRequests() async throws -> [FriendRequest]
    func acceptFriendRequest(id: FriendRequest.ID) async throws
    func denyFriendRequest(id: FriendRequest.ID) async throws
    /// Pending group invites addressed to the current user, newest first.
    func incomingGroupInvites() async throws -> [GroupInvite]
    /// Accepts a pending group invite, turning the caller into an active member.
    func acceptGroupInvite(id: GroupInvite.ID) async throws
    /// Declines a pending group invite; removes the row so a future re-invite is possible.
    func denyGroupInvite(id: GroupInvite.ID) async throws
}
