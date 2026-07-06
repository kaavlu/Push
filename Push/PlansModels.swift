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

    var pill: String { rawValue.capitalized }
}

struct HangoutPerson: Identifiable {
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

enum SwipeDirection { case left, right, up }
