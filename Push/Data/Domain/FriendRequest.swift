import Foundation

struct FriendRequest: Identifiable, Codable, Equatable {
    enum Status: String, Codable {
        case pending
        case accepted
        case denied
    }

    let id: String
    let requester: Person
    let createdAt: Date
    let status: Status
    let isUnread: Bool
}
