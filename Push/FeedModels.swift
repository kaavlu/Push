//
//  FeedModels.swift
//  Push
//
//  Feed shell models (Issue #9) — tabs + fixture filter chips.
//  Media carousel models live in FeedMediaModels.swift.
//

import Foundation

enum FeedTab: String, CaseIterable, Identifiable {
    case pushes
    case now

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pushes: return "Pushes"
        case .now: return "Now"
        }
    }
}

/// Preview / design-lab filter chips only. The app builds chips from the
/// viewer's groups via `MomentFeedFilter` (Issue #125).
enum FeedFilterFixtures {
    /// Same "no group predicate" id the repository-backed chips use.
    static let allID = MomentFeedFilter.allID

    static let items: [PushIvoryFilterItem] = [
        PushIvoryFilterItem(id: allID, title: "All"),
        PushIvoryFilterItem(id: "india", title: "India"),
        PushIvoryFilterItem(id: "michigan", title: "Michigan"),
        PushIvoryFilterItem(id: "exec", title: "Exec"),
    ]
}
