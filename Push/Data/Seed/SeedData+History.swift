//
//  SeedData+History.swift
//  Push
//
//  Past hangouts (recorded facts driving the calendar) and seeded feed
//  events (a materialized read model — no UI yet).
//

import Foundation

extension SeedData {

    // MARK: - Past hangouts

    static func standardHangouts(now: Date) -> [PastHangout] {
        [
            hangout(day: 3, index: 0, ["chitty", "ishan"], "Coffee run downtown", "10:00am–11:30am", now: now),
            hangout(day: 3, index: 1, ["viplove"], "Gym session", "6:00pm–7:30pm", now: now),
            hangout(day: 5, index: 0, ["chitty"], "Pre-dinner drinks", "5:30pm–7:00pm", cameFromPush: true, now: now),
            hangout(day: 5, index: 1, ["ram", "ohm", "rohan"], "Dinner at North Park", "7:00pm–9:30pm", now: now),
            hangout(day: 5, index: 2, ["ishan", "nitin"], "After-dinner walk", "9:30pm–10:30pm", now: now),
            hangout(day: 6, index: 0, ["ohm"], "Coffee at Blue Bottle", "11:00am–12:00pm", now: now),
            hangout(day: 10, index: 0, ["pranay", "ryan"], "Morning gym session", "7:00am–8:30am", now: now),
            hangout(day: 11, index: 0, ["rohan", "ryan", "ram"], "Watched the game at Ram's", "3:00pm–7:00pm", cameFromPush: true, now: now),
            hangout(day: 11, index: 1, ["roh"], "Late night drive", "10:00pm–11:30pm", now: now),
            hangout(day: 12, index: 0, ["chitty", "ishan", "viplove", "nitin"], "Pregame at Ishan's", "7:00pm–9:00pm", cameFromPush: true, now: now),
            hangout(day: 12, index: 1, ["chitty", "ishan"], "Drinks in Little Italy", "9:30pm–11:00pm", now: now),
            hangout(day: 12, index: 2, ["viplove"], "Last stop, rooftop bar", "11:30pm–1:00am", now: now),
            hangout(day: 17, index: 0, ["roh", "pranay"], "Walked the promenade", "4:00pm–6:00pm", now: now),
            hangout(day: 18, index: 0, ["ram", "ohm", "pranay", "rohan"], "Poker night at Ram's", "8:00pm–1:00am", now: now),
            hangout(day: 18, index: 1, ["ryan"], "Came by after poker", "11:00pm–12:00am", now: now),
            hangout(day: 22, index: 0, ["chitty"], "Coffee catch-up", "2:00pm–3:30pm", now: now),
            hangout(day: 23, index: 0, ["ishan", "viplove"], "Brunch at the spot", "11:00am–1:00pm", cameFromPush: true, now: now),
            hangout(day: 23, index: 1, ["rohan", "ryan", "pranay"], "Beach afternoon", "2:00pm–6:00pm", now: now),
            hangout(day: 23, index: 2, ["ram", "ohm"], "Dinner to end the day", "7:30pm–9:30pm", now: now)
        ]
    }

    private static func hangout(
        day: Int,
        index: Int,
        _ participantIDs: [String],
        _ note: String,
        _ timeRange: String,
        cameFromPush: Bool = false,
        now: Date
    ) -> PastHangout {
        PastHangout(
            id: "hangout-\(day)-\(index)",
            date: date(day: day, in: now),
            participantIDs: participantIDs,
            note: note,
            timeRange: timeRange,
            cameFromPush: cameFromPush
        )
    }

    private static func date(day: Int, in month: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month], from: month)
        components.day = day
        return Calendar.current.date(from: components) ?? month
    }

    // MARK: - Feed events

    static func standardFeedEvents(now: Date) -> [FeedEvent] {
        [
            FeedEvent(
                id: "feed-chitty-arrived",
                kind: .arrived,
                actorIDs: ["chitty"],
                placeID: "blue-bottle",
                groupID: nil,
                timestamp: now.addingTimeInterval(-3 * SeedTime.minute)
            ),
            FeedEvent(
                id: "feed-souvla-forming",
                kind: .groupForming,
                actorIDs: ["ishan", "viplove"],
                placeID: "souvla",
                groupID: "india",
                timestamp: now.addingTimeInterval(-10 * SeedTime.minute)
            ),
            FeedEvent(
                id: "feed-dolores-forming",
                kind: .groupForming,
                actorIDs: ["rohan", "ryan", "pranay"],
                placeID: "dolores-lawn",
                groupID: "michigan",
                timestamp: now.addingTimeInterval(-15 * SeedTime.minute)
            ),
            FeedEvent(
                id: "feed-coffee-push",
                kind: .pushCreated,
                actorIDs: ["chitty"],
                placeID: "blue-bottle",
                groupID: "india",
                timestamp: now.addingTimeInterval(-20 * SeedTime.minute)
            ),
            FeedEvent(
                id: "feed-food-push",
                kind: .pushCreated,
                actorIDs: ["ram"],
                placeID: "north-park",
                groupID: "michigan",
                timestamp: now.addingTimeInterval(-45 * SeedTime.minute)
            )
        ]
    }
}
