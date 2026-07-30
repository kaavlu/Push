//
//  HistoryContentBuilder.swift
//  Push
//
//  Presentation rows for the month History list/detail. Completed pushes
//  are primary; mock seed hangouts fill in non-push calendar richness.
//

import Foundation

enum HistoryContentBuilder {

    static func items(
        plans: [PushPlan],
        responses: [PushResponse],
        hangouts: [PastHangout],
        peopleByID: [Person.ID: Person],
        groupsByID: [FriendGroup.ID: FriendGroup],
        placesByID: [Place.ID: Place],
        now: Date,
        calendar: Calendar = .current
    ) -> [HistoryItemData] {
        let fromPlans = plans
            .filter { PushLifecycle.isHistorical($0, now: now) }
            .map { plan in
                item(
                    for: plan,
                    responses: responses.filter { $0.pushID == plan.id },
                    peopleByID: peopleByID,
                    groupsByID: groupsByID,
                    placesByID: placesByID,
                    calendar: calendar
                )
            }

        let planIDs = Set(fromPlans.map(\.id))
        let fromSeed = hangouts
            .filter { !planIDs.contains($0.id) }
            .map { hangout in
                item(for: hangout, peopleByID: peopleByID)
            }

        return (fromPlans + fromSeed).sorted { $0.date > $1.date }
    }

    private static func item(
        for plan: PushPlan,
        responses: [PushResponse],
        peopleByID: [Person.ID: Person],
        groupsByID: [FriendGroup.ID: FriendGroup],
        placesByID: [Place.ID: Place],
        calendar: Calendar
    ) -> HistoryItemData {
        let participants = responses
            .filter { $0.response == .in }
            .compactMap { peopleByID[$0.personID] }
            .map(hangoutPerson)
        let place = plan.placeID.flatMap { placesByID[$0] }
        let locationHint: String
        if let place {
            locationHint = plan.placeIsSuggested ? "Suggested: \(place.name)" : place.name
        } else {
            locationHint = plan.locationText ?? ""
        }
        return HistoryItemData(
            id: plan.id,
            date: calendar.startOfDay(for: plan.startsAt),
            title: plan.title,
            timeRange: timeRange(for: plan),
            locationHint: locationHint,
            groupName: plan.groupID.flatMap { groupsByID[$0]?.name } ?? "",
            participants: participants,
            cameFromPush: true
        )
    }

    private static func item(
        for hangout: PastHangout,
        peopleByID: [Person.ID: Person]
    ) -> HistoryItemData {
        HistoryItemData(
            id: hangout.id,
            date: hangout.date,
            title: hangout.note,
            timeRange: hangout.timeRange,
            locationHint: "",
            groupName: "",
            participants: hangout.participantIDs
                .compactMap { peopleByID[$0] }
                .map(hangoutPerson),
            cameFromPush: hangout.cameFromPush
        )
    }

    private static func timeRange(for plan: PushPlan) -> String {
        guard plan.hasExplicitTime else {
            return weekdayFormatter.string(from: plan.startsAt)
        }
        let time = timeFormatter.string(from: plan.startsAt)
        return plan.isApproximateTime ? "~\(time)" : time
    }

    private static func hangoutPerson(_ person: Person) -> HangoutPerson {
        HangoutPerson(
            id: person.id,
            name: person.displayName,
            imageAssetName: person.imageAssetPath ?? "",
            initials: person.initials
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
}
