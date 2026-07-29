import Foundation

struct FriendRequest: Identifiable, Codable, Equatable {
    enum Status: String, Codable {
        case pending
        case accepted
        case denied
    }

    let id: String
    let requester: Person
    let recipientID: Person.ID
    let createdAt: Date
    let status: Status
    let isUnread: Bool
    /// Server-derived for live incoming requests; fixture-backed in mock.
    /// The underlying friend identities remain private.
    let mutualFriendCount: Int

    init(
        id: String,
        requester: Person,
        recipientID: Person.ID,
        createdAt: Date,
        status: Status,
        isUnread: Bool,
        mutualFriendCount: Int = 0
    ) {
        self.id = id
        self.requester = requester
        self.recipientID = recipientID
        self.createdAt = createdAt
        self.status = status
        self.isUnread = isUnread
        self.mutualFriendCount = mutualFriendCount
    }
}

/// How the current user relates to a discovered person.
enum FriendshipRelation: Equatable {
    case none
    case outgoingPending(requestID: String)
    case incomingPending(requestID: String)
    case friends
}

/// One Add Friends search hit: public identity + relationship for the action button.
struct PersonSearchResult: Identifiable, Equatable {
    let person: Person
    let handle: String
    let relation: FriendshipRelation

    var id: Person.ID { person.id }
}

/// Someone the current user has blocked — identity only (no presence / status).
struct BlockedPerson: Identifiable, Equatable {
    let id: Person.ID
    let firstName: String
    let handle: String
    let imageAssetPath: String?
}

/// Directed block edge. Mock store only; live uses `user_blocks` via RPCs (Task 3).
struct UserBlock: Equatable {
    let blockerID: Person.ID
    let blockedID: Person.ID
}
