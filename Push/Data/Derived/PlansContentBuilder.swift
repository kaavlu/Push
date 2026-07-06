//
//  PlansContentBuilder.swift
//  Push
//
//  Derives Pushes-screen cards, social proof, and the hangout calendar from
//  canonical plans, responses, and recorded hangouts.
//

import Foundation

enum PlansContentBuilder {

    // MARK: - Push cards

    static func planData(
        plans: [PushPlan],
        responses: [PushResponse],
        groupsByID: [FriendGroup.ID: FriendGroup],
        placesByID: [Place.ID: Place],
        peopleByID: [Person.ID: Person],
        currentUserID: Person.ID,
        now: Date
    ) -> [PlanData] {
        plans.map { plan in
            let planResponses = responses.filter { $0.pushID == plan.id }
            let mine = planResponses.first { $0.personID == currentUserID }?.response ?? .pending
            let place = placesByID[plan.placeID]
            return PlanData(
                id: plan.id,
                title: plan.title,
                group: groupsByID[plan.groupID]?.name ?? plan.groupID,
                timeSignal: PushTimingFormatter.label(for: plan, now: now),
                socialProof: SocialProofFormatter.label(
                    plan: plan, responses: planResponses,
                    peopleByID: peopleByID, currentUserID: currentUserID
                ),
                locationHint: locationHint(place: place, isSuggested: plan.placeIsSuggested),
                status: pill(for: mine),
                isOwner: plan.creatorID == currentUserID,
                participants: participants(
                    responses: planResponses, peopleByID: peopleByID, currentUserID: currentUserID
                )
            )
        }
    }

    /// The presentation pill derives from my response; push lifecycle state
    /// stays canonical on PushPlan.
    static func pill(for response: PushResponse.Response) -> PlanStatus {
        switch response {
        case .pending: return .pending
        case .in: return .joined
        case .maybe: return .open
        case .out: return .waiting
        }
    }

    private static func locationHint(place: Place?, isSuggested: Bool) -> String {
        guard let place else { return "" }
        return isSuggested ? "Suggested: \(place.name)" : place.name
    }

    private static func participants(
        responses: [PushResponse],
        peopleByID: [Person.ID: Person],
        currentUserID: Person.ID
    ) -> [HangoutPerson] {
        responses
            .filter { $0.response == .in && $0.personID != currentUserID }
            .compactMap { peopleByID[$0.personID] }
            .map(hangoutPerson)
    }

    // MARK: - Calendar

    static func calendarDays(
        hangouts: [PastHangout],
        peopleByID: [Person.ID: Person],
        month: Date
    ) -> [CalendarDayData] {
        let calendar = Calendar.current
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: month)
            )
        else { return [] }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        return range.compactMap { day -> CalendarDayData? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else {
                return nil
            }
            let dayHangouts = hangouts.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let happened = dayHangouts.filter(\.didHappen)
            return CalendarDayData(
                id: formatter.string(from: date),
                date: date,
                pushCount: happened.count,
                hadPlan: happened.contains(where: \.cameFromPush),
                almostHappened: dayHangouts.contains { !$0.didHappen },
                hangouts: happened.map { entry(for: $0, peopleByID: peopleByID) }
            )
        }
    }

    private static func entry(
        for hangout: PastHangout,
        peopleByID: [Person.ID: Person]
    ) -> DayHangoutEntry {
        DayHangoutEntry(
            id: hangout.id,
            people: hangout.participantIDs.compactMap { peopleByID[$0] }.map(hangoutPerson),
            activityNote: hangout.note,
            duration: hangout.timeRange
        )
    }

    static func mostActiveGroup(
        hangouts: [PastHangout],
        memberships: [GroupMembership],
        groupsByID: [FriendGroup.ID: FriendGroup],
        groupOrder: [FriendGroup.ID]
    ) -> String {
        let membersByGroup: [FriendGroup.ID: Set<Person.ID>] = memberships
            .filter { $0.membershipStatus == .active }
            .reduce(into: [:]) { $0[$1.groupID, default: []].insert($1.personID) }

        var appearances: [FriendGroup.ID: Int] = [:]
        for hangout in hangouts where hangout.didHappen {
            for (groupID, members) in membersByGroup {
                appearances[groupID, default: 0] += hangout.participantIDs
                    .filter(members.contains).count
            }
        }
        let winner = groupOrder.max { (appearances[$0] ?? 0) < (appearances[$1] ?? 0) }
        return winner.flatMap { groupsByID[$0]?.name } ?? ""
    }

    private static func hangoutPerson(_ person: Person) -> HangoutPerson {
        HangoutPerson(
            id: person.id,
            name: person.displayName,
            imageAssetName: person.imageAssetPath ?? "",
            initials: person.initials
        )
    }
}

/// Social proof copy rules, reproducing today's five strings exactly.
private enum SocialProofFormatter {
    static func label(
        plan: PushPlan,
        responses: [PushResponse],
        peopleByID: [Person.ID: Person],
        currentUserID: Person.ID
    ) -> String {
        let others = responses.filter { $0.personID != currentUserID }
        let ins = others.filter { $0.response == .in }.compactMap { peopleByID[$0.personID] }
        let maybes = others.filter { $0.response == .maybe }.compactMap { peopleByID[$0.personID] }

        if plan.state == .happening, ins.count == 1, let there = ins.first {
            let suffix = maybes.count == 1 ? " · \(maybes[0].displayName) maybe" : ""
            return "\(there.displayName) is there\(suffix)"
        }
        if ins.count == 1, maybes.count == 1 {
            return "\(ins[0].displayName) in · \(maybes[0].displayName) maybe"
        }
        if maybes.isEmpty {
            return "\(ins.count) going"
        }
        return "\(ins.count) in · \(maybes.count) maybe"
    }
}
