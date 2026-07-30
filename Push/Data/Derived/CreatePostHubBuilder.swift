//
//  CreatePostHubBuilder.swift
//  Push
//
//  Maps repository reads onto the Create Post chooser rows (architecture S7
//  §6.2–6.3): `MomentSummary` → Existing Moments, historical `PushPlan` →
//  Past Pushes. Formatting only — visibility and capability decisions arrive
//  already made by the repository, and the one-Moment-per-Push exclusion here
//  is a chooser hint, never authorization (the RPC still rejects a reused Push).
//

import Foundation

enum CreatePostHubBuilder {

    // MARK: - Existing Moments

    static func existingMoments(
        from summaries: [MomentSummary],
        people: [Person.ID: Person],
        now: Date = Date()
    ) -> [CreatePostHistoryItem] {
        summaries.map { existingMoment(from: $0, people: people, now: now) }
    }

    static func existingMoment(
        from summary: MomentSummary,
        people: [Person.ID: Person],
        now: Date = Date()
    ) -> CreatePostHistoryItem {
        let moment = summary.moment
        let card = MomentFeedCardBuilder.card(from: summary, people: people, now: now)
        return CreatePostHistoryItem(
            id: moment.id,
            title: card.title,
            dateLabel: card.dateTimeLabel,
            locationTitle: moment.locationText,
            participants: card.participants,
            contributors: contributors(for: summary, people: people),
            mediaItems: card.items,
            style: .existingMoment(
                CreatePostContributionState.resolved(
                    youContributed: summary.capabilities.youContributed,
                    openForAdds: summary.capabilities.showOpenForAddsChip
                )
            )
        )
    }

    /// Distinct uploaders of viewer-visible media, first upload first. Ids with
    /// no cached `Person` are dropped rather than drawn as a nameless face —
    /// the same rule `MomentFeedCardBuilder` applies to tagged people.
    private static func contributors(
        for summary: MomentSummary,
        people: [Person.ID: Person]
    ) -> [FeedMediaParticipant] {
        var seen: Set<Person.ID> = []
        return summary.media.compactMap { media in
            guard seen.insert(media.uploaderID).inserted,
                  let person = people[media.uploaderID]
            else { return nil }
            return FeedMediaParticipant(
                id: person.id,
                displayName: person.displayName,
                imageAssetPath: person.imageAssetPath
            )
        }
    }

    // MARK: - Past Pushes

    /// Historical pushes that have no Moment yet, newest first. `momentPushIDs`
    /// are the Push slots this viewer can already see consumed — a Moment made
    /// by someone the viewer can't see leaves its Push listed here, and publish
    /// then fails with `momentExistsForPush` (contract §7 "Second Moment same Push").
    static func pastPushes(
        plans: [PushPlan],
        responses: [PushResponse],
        momentPushIDs: Set<PushPlan.ID>,
        peopleByID: [Person.ID: Person],
        placesByID: [Place.ID: Place],
        viewerID: Person.ID,
        now: Date = Date()
    ) -> [CreatePostHistoryItem] {
        let responsesByPush = Dictionary(grouping: responses, by: \.pushID)
        return plans
            .filter { PushLifecycle.isHistorical($0, now: now) }
            .filter { !momentPushIDs.contains($0.id) }
            .sorted { $0.startsAt > $1.startsAt }
            .map { plan in
                pastPush(
                    plan: plan,
                    responses: responsesByPush[plan.id] ?? [],
                    peopleByID: peopleByID,
                    placesByID: placesByID,
                    viewerID: viewerID
                )
            }
    }

    private static func pastPush(
        plan: PushPlan,
        responses: [PushResponse],
        peopleByID: [Person.ID: Person],
        placesByID: [Place.ID: Place],
        viewerID: Person.ID
    ) -> CreatePostHistoryItem {
        CreatePostHistoryItem(
            id: plan.id,
            title: plan.title,
            dateLabel: dateLabel(for: plan),
            locationTitle: locationTitle(for: plan, placesByID: placesByID),
            participants: prefillTags(
                responses: responses, peopleByID: peopleByID, viewerID: viewerID
            ),
            contributors: [],
            mediaItems: [],
            style: .pastPush
        )
    }

    /// Prefilled tags are the people who said they were in — never the creator's
    /// invite list, and never the viewer (the creator tag is implicit).
    /// Unknown ids (not an accepted friend of the viewer) are dropped: the
    /// server rejects those tags with `invalid tag`.
    private static func prefillTags(
        responses: [PushResponse],
        peopleByID: [Person.ID: Person],
        viewerID: Person.ID
    ) -> [FeedMediaParticipant] {
        responses
            .filter { $0.response == .in && $0.personID != viewerID }
            .sorted { $0.personID < $1.personID }
            .compactMap { peopleByID[$0.personID] }
            .map { person in
                FeedMediaParticipant(
                    id: person.id,
                    displayName: person.displayName,
                    imageAssetPath: person.imageAssetPath
                )
            }
    }

    private static func locationTitle(
        for plan: PushPlan,
        placesByID: [Place.ID: Place]
    ) -> String {
        if let place = plan.placeID.flatMap({ placesByID[$0] }) { return place.name }
        return plan.locationText ?? ""
    }

    /// "Sat · 4:30 PM", or the weekday alone when the Push had no explicit time.
    private static func dateLabel(for plan: PushPlan) -> String {
        let day = weekdayFormatter.string(from: plan.startsAt)
        guard plan.hasExplicitTime else { return day }
        let time = timeFormatter.string(from: plan.startsAt)
        return "\(day) · \(plan.isApproximateTime ? "~" : "")\(time)"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
}
