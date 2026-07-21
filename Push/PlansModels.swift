// Push/PlansModels.swift
import Foundation

struct PlanData: Identifiable {
    let id: String
    let title: String
    let group: String
    let timeSignal: String
    let socialProof: String
    let locationHint: String
    var status: PlanStatus
    let isOwner: Bool
    /// People who are in (excludes the current user).
    let participants: [HangoutPerson]
    /// People who tapped maybe (excludes the current user).
    let maybeParticipants: [HangoutPerson]
    /// Creator's free-text details; nil/empty when none was added.
    let note: String?
    /// Street-level address of the push's place, if known.
    let address: String
    /// Distance from the current user to the place, e.g. "4.3 mi away".
    /// nil when the user's location or the place is unknown.
    let distanceLabel: String?

    init(
        id: String,
        title: String,
        group: String,
        timeSignal: String,
        socialProof: String,
        locationHint: String,
        status: PlanStatus,
        isOwner: Bool,
        participants: [HangoutPerson] = [],
        maybeParticipants: [HangoutPerson] = [],
        note: String? = nil,
        address: String = "",
        distanceLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.group = group
        self.timeSignal = timeSignal
        self.socialProof = socialProof
        self.locationHint = locationHint
        self.status = status
        self.isOwner = isOwner
        self.participants = participants
        self.maybeParticipants = maybeParticipants
        self.note = note
        self.address = address
        self.distanceLabel = distanceLabel
    }
}

enum PlanStatus: String, Equatable {
    case pending, joined, open, waiting, locked, happening

    /// `.open`/`.waiting` are internal names for "responded maybe" / "responded
    /// no" (see `PlansContentBuilder.pill(for:)`); the chip reads "Maybe"/"Pass"
    /// so the card reflects the friend's actual decision.
    var pill: String {
        switch self {
        case .open:    return "Maybe"
        case .waiting: return "Pass"
        default:       return rawValue.capitalized
        }
    }
}

struct HangoutPerson: Identifiable, Equatable {
    let id: String
    let name: String
    let imageAssetName: String
    let initials: String
}

struct DayHangoutEntry: Identifiable {
    let id: String
    let people: [HangoutPerson]
    let activityNote: String
    let duration: String
}

struct CalendarDayData: Identifiable {
    let id: String
    let date: Date
    let pushCount: Int
    let hadPlan: Bool
    let almostHappened: Bool
    let hangouts: [DayHangoutEntry]
}

/// Read-only History list/detail row derived from a completed push (or mock seed hangout).
struct HistoryItemData: Identifiable, Equatable {
    let id: String
    let date: Date
    let title: String
    let timeRange: String
    let locationHint: String
    let groupName: String
    let participants: [HangoutPerson]
    let cameFromPush: Bool
    let didHappen: Bool
}

enum SwipeDirection { case left, right, up }
