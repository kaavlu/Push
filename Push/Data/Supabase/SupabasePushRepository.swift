//
//  SupabasePushRepository.swift
//  Push
//
//  Pushes are multi-actor (creator writes the push + seeds invitees; each
//  recipient writes their own RSVP), unlike the single-owner profile writes,
//  so per-operation RLS backs this instead of a single `*_update_self` policy
//  (see `supabase/migrations/0006_pushes.sql`).
//

import Foundation
import Supabase

final class SupabasePushRepository: PushRepository {
    private let store: LiveDataStore
    private let currentUserID: String

    init(store: LiveDataStore, currentUserID: String) {
        self.store = store
        self.currentUserID = currentUserID
    }

    func activePlans() async throws -> [PushPlan] {
        try await store.pushes().map { $0.pushPlan() }.filter { $0.cancelledAt == nil }
    }

    func responses() async throws -> [PushResponse] {
        try await store.pushResponses().map { $0.pushResponse() }
    }

    func setCurrentUserResponse(planID: PushPlan.ID, response: PushResponse.Response) async throws {
        let payload = PushResponsePayload(
            push_id: planID,
            person_id: currentUserID,
            response: response.rawValue,
            responded_at: response == .pending ? nil : PushDateFormatting.string(Date())
        )
        try await store.upsertResponse(payload)
        await store.notifyPushesChanged()
    }

    // Calendar and map places are out of scope for pushes persistence (see
    // plan); live mode has no backing table for either yet.
    func pastHangouts(forMonthContaining date: Date) async throws -> [PastHangout] { [] }
    func allPlaces() async throws -> [Place] { [] }

    func createPush(_ draft: PushDraft) async throws -> PushPlan.ID {
        let parsed = PushRecipientResolver.parse(draft.recipientIDs)
        let memberships = try await store.memberships().map { $0.membership() }
        let invitees = try await nonBlockedInvitees(
            groupIDs: parsed.groupIDs, friendIDs: parsed.friendIDs, creatorID: draft.creatorID,
            memberships: memberships
        )
        let now = Date()
        let expiresAt = draft.startsAt.addingTimeInterval(PushWriteConstants.expiryWindow)

        let insertPayload = PushInsertPayload(
            title: draft.title,
            group_id: parsed.singleGroupOnly ? parsed.groupIDs[0] : nil,
            creator_id: draft.creatorID,
            starts_at: PushDateFormatting.string(draft.startsAt),
            has_explicit_time: true,
            is_approximate_time: false,
            expires_at: PushDateFormatting.string(expiresAt),
            audience: parsed.singleGroupOnly ? "group" : "invitees_only",
            note: draft.notes.isEmpty ? nil : draft.notes,
            location_text: draft.locationText.isEmpty ? nil : draft.locationText
        )
        let pushRow = try await store.insertPush(insertPayload)

        let creatorResponse = PushResponsePayload(
            push_id: pushRow.id, person_id: draft.creatorID,
            response: PushResponse.Response.in.rawValue, responded_at: PushDateFormatting.string(now)
        )
        let inviteeResponses = invitees.map { personID in
            PushResponsePayload(
                push_id: pushRow.id, person_id: personID,
                response: PushResponse.Response.pending.rawValue, responded_at: nil
            )
        }
        try await store.insertResponses([creatorResponse] + inviteeResponses)
        await store.notifyPushesChanged()
        return pushRow.id
    }

    func updatePush(planID: PushPlan.ID, with draft: PushDraft) async throws {
        guard let existing = try await store.pushes().first(where: { $0.id == planID })?.pushPlan() else {
            return
        }
        let parsed = PushRecipientResolver.parse(draft.recipientIDs)
        let memberships = try await store.memberships().map { $0.membership() }
        let invitees = try await nonBlockedInvitees(
            groupIDs: parsed.groupIDs, friendIDs: parsed.friendIDs, creatorID: existing.creatorID,
            memberships: memberships
        )
        let expiresAt = draft.startsAt.addingTimeInterval(PushWriteConstants.expiryWindow)
        let updatePayload = PushUpdatePayload(
            title: draft.title,
            group_id: parsed.singleGroupOnly ? parsed.groupIDs[0] : nil,
            starts_at: PushDateFormatting.string(draft.startsAt),
            expires_at: PushDateFormatting.string(expiresAt),
            audience: parsed.singleGroupOnly ? "group" : "invitees_only",
            note: draft.notes.isEmpty ? nil : draft.notes,
            location_text: draft.locationText.isEmpty ? nil : draft.locationText,
            updated_at: PushDateFormatting.string(Date())
        )
        _ = try await store.updatePush(id: planID, payload: updatePayload)
        try await reconcileResponses(planID: planID, creatorID: existing.creatorID, invitees: invitees)
        await store.notifyPushesChanged()
    }

    func cancelPush(planID: PushPlan.ID) async throws {
        let payload = PushCancelPayload(cancelled_at: PushDateFormatting.string(Date()))
        _ = try await store.cancelPush(id: planID, payload: payload)
        await store.notifyPushesChanged()
    }

    // `push_responses.push_id` cascades on delete (0006_pushes.sql), so the
    // Postgres row removal alone clears out RSVPs; no reconciliation needed.
    func deletePush(planID: PushPlan.ID) async throws {
        try await store.deletePush(id: planID)
        await store.notifyPushesChanged()
    }

    /// Keeps existing RSVPs untouched, seeds pending rows for newly added
    /// invitees, and drops rows for invitees removed from the recipient set
    /// — the same net effect as `LocalPushRepository`'s wholesale response
    /// replacement, expressed as an add/remove diff since Postgres has no
    /// equivalent one-shot "replace all responses for this push" write.
    private func reconcileResponses(
        planID: PushPlan.ID, creatorID: Person.ID, invitees: Set<Person.ID>
    ) async throws {
        let current = try await store.pushResponses().filter { $0.push_id == planID }
        let currentPersonIDs = Set(current.map(\.person_id))
        let desiredPersonIDs = invitees.union([creatorID])
        let toAdd = desiredPersonIDs.subtracting(currentPersonIDs)
        let toRemove = currentPersonIDs.subtracting(desiredPersonIDs)

        let newRows = toAdd.map { personID in
            PushResponsePayload(
                push_id: planID, person_id: personID,
                response: personID == creatorID
                    ? PushResponse.Response.in.rawValue : PushResponse.Response.pending.rawValue,
                responded_at: personID == creatorID ? PushDateFormatting.string(Date()) : nil
            )
        }
        try await store.insertResponses(newRows)
        try await store.deleteResponses(pushID: planID, personIDs: Array(toRemove))
    }

    /// Drops blocked **direct** friend tokens only; group-expanded members stay
    /// (group membership rules apply, not soft-hide) — mirrors
    /// `LocalPushRepository.nonBlockedInvitees`.
    private func nonBlockedInvitees(
        groupIDs: [FriendGroup.ID],
        friendIDs: [Person.ID],
        creatorID: Person.ID,
        memberships: [GroupMembership]
    ) async throws -> Set<Person.ID> {
        let blockedIDs = Set(
            (try await store.listBlockedUsers()).map { $0.id.lowercased() }
        )
        let allowedFriendIDs = friendIDs.filter {
            !blockedIDs.contains($0.lowercased())
        }
        return PushRecipientResolver.invitees(
            groupIDs: groupIDs, friendIDs: allowedFriendIDs,
            memberships: memberships, creatorID: creatorID
        )
    }
}

private enum PushWriteConstants {
    /// Pushes expire six hours after their start, matching `LocalPushRepository`.
    static let expiryWindow: TimeInterval = 6 * 60 * 60
}
