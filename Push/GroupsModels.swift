//
//  GroupsModels.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import Combine
import Foundation

struct PushGroupData: Identifiable, Equatable {
    let id: String
    let name: String
    let memberCount: Int
    let memberIDs: [String]
    let status: PushGroupStatus
    let activeNowCount: Int
    let nearbyCount: Int
    let planCount: Int
    let imageAssetName: String?
    let fallbackSymbol: String
    let fallbackInitials: String
}

enum PushGroupStatus: String, Equatable {
    case activeNow = "Active now"
    case quiet = "Quiet"
    case planLive = "Push live"
    case nearby = "Nearby"
    case freeSoon = "Free soon"

    var title: String { rawValue }
}

struct PushGroupStat: Identifiable, Equatable {
    let id: String
    let value: Int
    let label: String
}

struct PushGroupMemberData: Identifiable, Equatable {
    let id: String
    let name: String
    let avatarPlaceholder: String
    let profileImageAssetName: String?
    let availability: FriendAvailabilityState?
}

@MainActor
final class GroupsViewModel: ObservableObject {
    @Published private(set) var groups: [PushGroupData] = []
    @Published private(set) var selectedGroupID: String?
    @Published private(set) var presentedGroupID: String?
    @Published private(set) var loadState: LoadState<[PushGroupData]> = .idle

    private let container: AppDataContainer?
    private var membersByGroupID: [String: [PushGroupMemberData]] = [:]

    init(container: AppDataContainer = .shared) {
        self.container = container
        Task { await load() }
    }

    /// Preview/test seam: serve injected cards without touching repositories.
    init(groups: [PushGroupData]) {
        container = nil
        self.groups = groups
        selectedGroupID = groups.first?.id
        loadState = .loaded(groups)
    }

    func load() async {
        guard let container else { return }
        loadState = .loading
        do {
            let groupList = try await container.groups.groups()
            let memberships = try await container.groups.memberships()
            let statuses = try await container.friends.presenceStatuses()
            let plans = try await container.pushes.activePlans()
            let friendList = try await container.friends.friends()
            let user = try await container.friends.currentUser()

            let statusesByPersonID = Dictionary(
                uniqueKeysWithValues: statuses.map { ($0.personID, $0) }
            )
            let peopleByID = Dictionary(
                uniqueKeysWithValues: (friendList + [user]).map { ($0.id, $0) }
            )
            let cards = GroupContentBuilder.groupCards(
                groups: groupList,
                memberships: memberships,
                statuses: statusesByPersonID,
                plans: plans,
                now: Date()
            )
            membersByGroupID = Dictionary(uniqueKeysWithValues: groupList.map { group in
                (
                    group.id,
                    GroupContentBuilder.members(
                        groupID: group.id,
                        memberships: memberships,
                        people: peopleByID,
                        statuses: statusesByPersonID
                    )
                )
            })
            groups = cards
            if selectedGroupID == nil { selectedGroupID = cards.first?.id }
            loadState = .loaded(cards)
        } catch {
            loadState = .failed(error)
        }
    }

    func stats(for group: PushGroupData) -> [PushGroupStat] {
        [
            PushGroupStat(id: "active-now", value: group.activeNowCount, label: "Active now"),
            PushGroupStat(id: "nearby", value: group.nearbyCount, label: "Nearby"),
            PushGroupStat(id: "plans", value: group.planCount, label: "Pushes")
        ]
    }

    func isSelected(_ group: PushGroupData) -> Bool {
        selectedGroupID == group.id
    }

    func select(_ group: PushGroupData) {
        selectedGroupID = group.id
    }

    func openDetail(for group: PushGroupData) {
        selectedGroupID = group.id
        presentedGroupID = group.id
    }

    func closeDetail() {
        presentedGroupID = nil
    }

    func group(for id: String?) -> PushGroupData? {
        groups.first { $0.id == id }
    }

    func members(for group: PushGroupData) -> [PushGroupMemberData] {
        membersByGroupID[group.id] ?? []
    }
}

enum GroupsMockData {
    static let groups: [PushGroupData] = RealWorldMockData.groups.map { group in
        let groupInitials = initials(for: group.name)
        return PushGroupData(
            id: group.id,
            name: group.name,
            memberCount: group.memberIDs.count,
            memberIDs: group.memberIDs,
            status: group.status,
            activeNowCount: group.activeNowCount,
            nearbyCount: group.nearbyCount,
            planCount: group.planCount,
            imageAssetName: group.imageAssetName,
            fallbackSymbol: groupInitials,
            fallbackInitials: groupInitials
        )
    }

    private static func initials(for groupName: String) -> String {
        groupName.split(separator: " ")
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}

enum SeededGroupFriends {
    static func members(for memberIDs: [String]) -> [PushGroupMemberData] {
        memberIDs.compactMap { seededFriendsByID[$0] }
    }

    private static var seededFriendsByID: [String: PushGroupMemberData] {
        Dictionary(
            uniqueKeysWithValues: RealWorldMockData.friends.map { friend in
                (
                    friend.id,
                    PushGroupMemberData(
                        id: friend.id,
                        name: friend.displayName,
                        avatarPlaceholder: friend.initials,
                        profileImageAssetName: friend.imageAssetName,
                        availability: availability(for: friend.id)
                    )
                )
            }
        )
    }

    private static func availability(for id: String) -> FriendAvailabilityState {
        switch id {
        case "chitty", "ishan":
            return .freeNow
        case "nitin", "viplove", "rohan":
            return .joinable
        case "ram", "ryan":
            return .maybeDown
        case "ohm":
            return .busy
        case "pranay":
            return .freeSoon
        default:
            return .unavailable
        }
    }
}
