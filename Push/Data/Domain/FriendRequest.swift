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
