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

/// Isolated fixture filters for the Feed shell until live group data drives chips.
enum FeedFilterFixtures {
    static let allID = "all"

    static let items: [PushIvoryFilterItem] = [
        PushIvoryFilterItem(id: allID, title: "All"),
        PushIvoryFilterItem(id: "india", title: "India"),
        PushIvoryFilterItem(id: "michigan", title: "Michigan"),
        PushIvoryFilterItem(id: "exec", title: "Exec"),
    ]
}
