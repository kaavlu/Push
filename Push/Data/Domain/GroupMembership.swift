//
//  GroupMembership.swift
//  Push
//

import Foundation

struct GroupMembership: Identifiable, Codable, Equatable {
    enum Role: String, Codable { case owner, member }
    enum SharingLevel: String, Codable { case full, availabilityOnly, hidden }
    enum Status: String, Codable { case active, invited, left }

    let id: String
    let personID: Person.ID
    let groupID: FriendGroup.ID
    let role: Role
    let sharingLevel: SharingLevel
    let membershipStatus: Status
    let joinedAt: Date
}
