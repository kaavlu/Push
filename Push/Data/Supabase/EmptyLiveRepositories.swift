// Push/Data/Supabase/EmptyLiveRepositories.swift
import Foundation

/// Day-1 live mode has no pushes or feed (out of scope). Reads are empty;
/// writes are unsupported. This keeps mock data out of authenticated sessions (R1).
final class EmptyLivePushRepository: PushRepository {
    func activePlans() async throws -> [PushPlan] { [] }
    func responses() async throws -> [PushResponse] { [] }
    func setCurrentUserResponse(planID: PushPlan.ID, response: PushResponse.Response) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
    func pastHangouts(forMonthContaining date: Date) async throws -> [PastHangout] { [] }
    func allPlaces() async throws -> [Place] { [] }
    func createPush(_ draft: PushDraft) async throws -> PushPlan.ID {
        throw SupabaseRepositoryError.writeNotSupported
    }
    func updatePush(planID: PushPlan.ID, with draft: PushDraft) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
}

final class EmptyLiveFeedRepository: FeedRepository {
    func events() async throws -> [FeedEvent] { [] }
}

final class EmptyLiveAlertRepository: AlertRepository {
    func incomingFriendRequests() async throws -> [FriendRequest] { [] }
    func acceptFriendRequest(id: FriendRequest.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
    func denyFriendRequest(id: FriendRequest.ID) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
}
