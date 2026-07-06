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
    let participants: [HangoutPerson]

    init(
        id: String,
        title: String,
        group: String,
        timeSignal: String,
        socialProof: String,
        locationHint: String,
        status: PlanStatus,
        isOwner: Bool,
        participants: [HangoutPerson] = []
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
