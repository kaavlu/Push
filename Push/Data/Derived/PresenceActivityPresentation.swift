//
//  PresenceActivityPresentation.swift
//  Push
//
//  Issue #109 — single mapping from presence activity fields to friend-facing
//  labels/symbols. Builders call this; Views/ViewModels do not re-compose
//  activity from place or invent motion copy.
//

import Foundation

enum PresenceActivityPresentation {

    /// Default SF symbol when activity is missing or symbol is blank.
    static let defaultSymbolName = "mappin"
    static let aroundFallback = "Around"
    static let hiddenStatusText = "Hidden right now"
    static let hiddenSymbolName = "moon.zzz.fill"

    private static let atPrefix = "At "

    /// Friend-surface activity fields derived from canonical presence.
    struct SurfaceFields: Equatable {
        /// Raw activity name (`activity_name`), empty when absent.
        let activityName: String
        /// SF symbol for rows / pucks / detail cards.
        let activitySymbolName: String
        /// Compact map badge text (leading `At ` stripped when present).
        let activityDisplayText: String
        /// List / detail status line.
        let venueStatusText: String
    }

    // MARK: - Visible presence

    static func fields(from presence: VisiblePresence) -> SurfaceFields {
        fields(
            activity: presence.activity,
            statusNote: presence.statusNote,
            placeDisplayName: presence.placeInfo?.displayName,
            isVaguePlace: presence.placeInfo?.isVague ?? false,
            availabilityTitle: presence.availability?.title
        )
    }

    // MARK: - Core mapping

    static func fields(
        activity: PresenceActivity?,
        statusNote: String?,
        placeDisplayName: String?,
        isVaguePlace: Bool = false,
        availabilityTitle: String? = nil
    ) -> SurfaceFields {
        let activityName = trimmed(activity?.name)
        let symbolName = symbol(from: activity)
        let displayText = badgeText(
            activityName: activityName,
            placeDisplayName: placeDisplayName
        )
        let status = statusLine(
            activityName: activityName,
            statusNote: trimmed(statusNote),
            placeDisplayName: placeDisplayName,
            isVaguePlace: isVaguePlace,
            availabilityTitle: availabilityTitle
        )
        return SurfaceFields(
            activityName: activityName,
            activitySymbolName: symbolName,
            activityDisplayText: displayText,
            venueStatusText: status
        )
    }

    /// Hidden / unpublished friend row — no live activity.
    static func hiddenFields() -> SurfaceFields {
        SurfaceFields(
            activityName: "",
            activitySymbolName: hiddenSymbolName,
            activityDisplayText: "",
            venueStatusText: hiddenStatusText
        )
    }

    // MARK: - Detail / hangout lines

    /// Individual or hangout status card — prefer builder status line, then activity.
    static func detailStatusLine(
        activityName: String,
        venueStatusText: String
    ) -> String {
        let venue = trimmed(venueStatusText)
        if !venue.isEmpty { return venue }
        let activity = trimmed(activityName)
        if !activity.isEmpty { return activity }
        return aroundFallback
    }

    // MARK: - Internals

    private static func symbol(from activity: PresenceActivity?) -> String {
        let name = trimmed(activity?.symbolName)
        return name.isEmpty ? defaultSymbolName : name
    }

    /// Badge prefers compact place label when activity is `At {place}`;
    /// otherwise the activity name (Walking / Chilling / …).
    private static func badgeText(
        activityName: String,
        placeDisplayName: String?
    ) -> String {
        if activityName.isEmpty {
            return placeDisplayName ?? ""
        }
        if let placeOnly = strippedAtPlaceName(from: activityName) {
            let place = trimmed(placeDisplayName)
            // Prefer a real place short name when it is not just the full activity string.
            if !place.isEmpty, place != activityName {
                return place
            }
            return placeOnly
        }
        return activityName
    }

    /// Status line priority: curated note → activity → place → availability → Around.
    /// Notes win so seed social lines (`With Ishan`) and composition `At {place}`
    /// notes keep their wording; empty-note motion activities surface activity name.
    private static func statusLine(
        activityName: String,
        statusNote: String,
        placeDisplayName: String?,
        isVaguePlace: Bool,
        availabilityTitle: String?
    ) -> String {
        if !statusNote.isEmpty { return statusNote }
        if !activityName.isEmpty { return activityName }
        if let place = placeDisplayName, !place.isEmpty {
            return isVaguePlace ? "Near \(place)" : "At \(place)"
        }
        if let title = availabilityTitle, !title.isEmpty { return title }
        return aroundFallback
    }

    private static func strippedAtPlaceName(from activityName: String) -> String? {
        guard activityName.hasPrefix(atPrefix) else { return nil }
        let rest = String(activityName.dropFirst(atPrefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return rest.isEmpty ? nil : rest
    }

    private static func trimmed(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
