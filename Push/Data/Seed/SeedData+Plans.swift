//
//  SeedData+Plans.swift
//  Push
//
//  Active pushes and their response rows. Social proof, pills, and timing
//  labels all derive from these — the seeded values reproduce today's copy.
//

import Foundation

extension SeedData {

    // MARK: - Plans

    static func standardPlans(now: Date) -> [PushPlan] {
        let saturday = 7
        let friday = 6
        return [
            plan(
                "food-tonight", title: "Food tonight?", groupID: "michigan", creatorID: "ram",
                startsAt: today(hour: 20, minute: 0, relativeTo: now),
                placeID: "north-park", placeIsSuggested: true, state: .collecting, now: now,
                note: "Thinking tacos or the new ramen spot — open to ideas. Street parking is easy after 7."
            ),
            plan(
                "gym-later", title: "Gym later", groupID: "exec", creatorID: SeedIDs.currentUser,
                startsAt: today(hour: 19, minute: 45, relativeTo: now),
                isApproximateTime: true,
                placeID: "crunch", placeIsSuggested: false, state: .locked, now: now,
                note: "Push + legs day. Bring the guest pass if you're not a member."
            ),
            plan(
                "coffee", title: "Coffee?", groupID: "india", creatorID: "chitty",
                startsAt: now.addingTimeInterval(-5 * SeedTime.minute),
                placeID: "blue-bottle", placeIsSuggested: false, state: .happening, now: now,
                note: "Grabbing a table outside. Text me if you can't find it."
            ),
            plan(
                "drinks-friday", title: "Drinks Friday?", groupID: "michigan", creatorID: SeedIDs.currentUser,
                startsAt: next(weekday: friday, hour: 21, minute: 0, after: now),
                placeID: "little-italy", placeIsSuggested: true, state: .collecting, now: now,
                note: "Rooftop bar has a dress code — no sneakers. Reservation under my name at 9."
            ),
            plan(
                "poker-night", title: "Poker night", groupID: "exec", creatorID: "ram",
                startsAt: next(weekday: saturday, hour: 19, minute: 0, after: now),
                hasExplicitTime: false,
                placeID: "rams-place", placeIsSuggested: false, state: .collecting, now: now,
                note: "$20 buy-in, cash only. I've got snacks, bring your own drinks."
            )
        ]
    }

    private static func plan(
        _ id: String,
        title: String,
        groupID: String,
        creatorID: String,
        startsAt: Date,
        hasExplicitTime: Bool = true,
        isApproximateTime: Bool = false,
        placeID: String,
        placeIsSuggested: Bool,
        state: PushPlan.State,
        now: Date,
        note: String? = nil
    ) -> PushPlan {
        PushPlan(
            id: id,
            title: title,
            groupID: groupID,
            creatorID: creatorID,
            createdAt: now.addingTimeInterval(-SeedTime.hour),
            updatedAt: now,
            startsAt: startsAt,
            hasExplicitTime: hasExplicitTime,
            isApproximateTime: isApproximateTime,
            expiresAt: startsAt.addingTimeInterval(SeedTime.sixHours),
            cancelledAt: nil,
            placeID: placeID,
            placeIsSuggested: placeIsSuggested,
            state: state,
            audience: .group,
            note: note
        )
    }

    // MARK: - Responses

    static func standardResponses(now: Date) -> [PushResponse] {
        [
            // Food tonight? — "3 in · 2 maybe", my pill Pending.
            response("food-tonight", "rohan", .in, now: now),
            response("food-tonight", "ryan", .in, now: now),
            response("food-tonight", "pranay", .in, now: now),
            response("food-tonight", "ram", .maybe, now: now),
            response("food-tonight", "ohm", .maybe, now: now),
            response("food-tonight", SeedIDs.currentUser, .pending, now: now),
            // Gym later — "4 going", my pill Joined. Responders outside the
            // Exec group are a retained quirk of today's content.
            response("gym-later", "chitty", .in, now: now),
            response("gym-later", "ishan", .in, now: now),
            response("gym-later", "viplove", .in, now: now),
            response("gym-later", "ram", .in, now: now),
            response("gym-later", SeedIDs.currentUser, .in, now: now),
            // Coffee? — "Chitty is there · Ishan maybe", my pill Open.
            response("coffee", "chitty", .in, now: now),
            response("coffee", "ishan", .maybe, now: now),
            response("coffee", SeedIDs.currentUser, .maybe, now: now),
            // Drinks Friday? — "2 in · 1 maybe", my pill Pending.
            response("drinks-friday", "rohan", .in, now: now),
            response("drinks-friday", "ryan", .in, now: now),
            response("drinks-friday", "pranay", .maybe, now: now),
            response("drinks-friday", SeedIDs.currentUser, .pending, now: now),
            // Poker night — "Ram in · Ohm maybe", my pill Waiting.
            response("poker-night", "ram", .in, now: now),
            response("poker-night", "ohm", .maybe, now: now),
            response("poker-night", SeedIDs.currentUser, .out, now: now)
        ]
    }

    private static func response(
        _ pushID: String,
        _ personID: String,
        _ value: PushResponse.Response,
        now: Date
    ) -> PushResponse {
        PushResponse(
            id: "\(pushID)-\(personID)",
            pushID: pushID,
            personID: personID,
            response: value,
            respondedAt: value == .pending ? nil : now.addingTimeInterval(-SeedTime.halfHour),
            readyState: .unknown
        )
    }
}
