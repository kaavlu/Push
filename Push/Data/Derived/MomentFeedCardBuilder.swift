//
//  MomentFeedCardBuilder.swift
//  Push
//
//  Maps viewer-scoped `MomentSummary` rows onto the approved Feed › Pushes
//  presentation models (Issue #125 / architecture S6 §6.1). Repository reads
//  arrive already block-filtered and capability-stamped, so this file only
//  formats — it never re-applies visibility rules.
//

import Foundation

enum MomentFeedCardBuilder {

    /// One card per Moment, in the order the repository returned them (the
    /// server's `(last_activity_at, id) desc` page order).
    static func cards(
        from summaries: [MomentSummary],
        people: [Person.ID: Person],
        now: Date = Date()
    ) -> [FeedMediaCarouselData] {
        summaries.map { card(from: $0, people: people, now: now) }
    }

    static func card(
        from summary: MomentSummary,
        people: [Person.ID: Person],
        now: Date = Date()
    ) -> FeedMediaCarouselData {
        let moment = summary.moment
        return FeedMediaCarouselData(
            id: moment.id,
            items: summary.media.map(mediaItem(for:)),
            title: displayTitle(moment.title),
            locationTitle: moment.locationText,
            dateTimeLabel: dateTimeLabel(for: moment.publishedAt, now: now),
            participants: participants(for: summary, people: people),
            contributorName: contributorName(for: summary, people: people),
            // Add yours is the tagged-only affordance; the server re-checks it.
            canAddYours: summary.capabilities.canAddMedia
        )
    }

    // MARK: - Media

    private static func mediaItem(for media: MomentMedia) -> FeedMediaItem {
        FeedMediaItem(
            id: media.id,
            kind: media.kind == .video ? .video : .photo,
            source: source(for: media)
        )
    }

    /// `AvatarImageLoader` resolves bundle assets, local files, and HTTPS from
    /// the same string, so mock seed paths and live public URLs share one case.
    /// Videos render their poster still — playback is out of scope.
    private static func source(for media: MomentMedia) -> FeedMediaSource {
        let path: String? = media.kind == .video
            ? (media.posterURL ?? media.posterPath)
            : media.publicURL
        guard let path, !path.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .missing
        }
        return .assetPath(path)
    }

    // MARK: - People

    /// Tagged people in server order (creator first). Ids without a cached
    /// `Person` are dropped rather than rendered as a nameless face — the same
    /// rule `GroupContentBuilder` uses for memberships.
    private static func participants(
        for summary: MomentSummary,
        people: [Person.ID: Person]
    ) -> [FeedMediaParticipant] {
        summary.taggedPersonIDs.compactMap { personID in
            guard let person = people[personID] else { return nil }
            return FeedMediaParticipant(
                id: person.id,
                displayName: person.displayName,
                imageAssetPath: person.imageAssetPath
            )
        }
    }

    /// Attribution for the visible cover item. Empty when the uploader is not
    /// in the viewer's people cache — the card then shows names only.
    private static func contributorName(
        for summary: MomentSummary,
        people: [Person.ID: Person]
    ) -> String {
        guard let uploaderID = summary.coverMedia?.uploaderID else { return "" }
        return people[uploaderID]?.displayName ?? ""
    }

    // MARK: - Copy

    private static func displayTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? MomentFeedCopy.untitledMoment : trimmed
    }

    /// "Today · 8:00 PM" / "Fri · 9:15 PM" / "Mar 3 · 4:30 PM" — publish time,
    /// not `lastActivityAt`, so a late "Add yours" never restamps the hang.
    private static func dateTimeLabel(for date: Date, now: Date) -> String {
        "\(dayLabel(for: date, now: now)) · \(timeFormatter.string(from: date))"
    }

    private static func dayLabel(for date: Date, now: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if (0...MomentFeedFormatting.weekdayWindowDays).contains(days) {
            return weekdayFormatter.string(from: date)
        }
        return monthDayFormatter.string(from: date)
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

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

enum MomentFeedFormatting {
    /// Within a week reads as a weekday ("Fri"); older falls back to a date.
    static let weekdayWindowDays = 6
}

enum MomentFeedCopy {
    static let untitledMoment = "Untitled moment"
    static let emptyTitle = "No moments yet"
    static let emptyMessage = "Photos from your pushes will show up here."
    /// Group chip selected with nothing in it yet.
    static let emptyGroupMessage = "Nothing from this group yet."
    static let surfaceName = "moments"
    static let loadMoreFailed = "Couldn't load more moments. Try again."
}
