//
//  FeedViewModel.swift
//  Push
//
//  Session state for the Feed shell + media carousel fixtures (Issue #9).
//

import Foundation
import Combine

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var selectedTab: FeedTab = .pushes
    /// Persists across Pushes/Now switches for the session.
    @Published var selectedFilterID: String = FeedFilterFixtures.allID

    /// Fixture media stacks for the Pushes tab until live feed cards land.
    let mediaCarousels: [FeedMediaCarouselData]

    let filterItems: [PushIvoryFilterItem] = FeedFilterFixtures.items

    init(mediaCarousels: [FeedMediaCarouselData] = FeedMediaCarouselFixtures.feedPushesPreviewStack) {
        self.mediaCarousels = mediaCarousels
    }

    var selectedTabID: String {
        get { selectedTab.rawValue }
        set { selectedTab = FeedTab(rawValue: newValue) ?? .pushes }
    }

    func selectTab(_ tab: FeedTab) {
        selectedTab = tab
    }

    func selectFilter(id: String) {
        guard filterItems.contains(where: { $0.id == id }) else { return }
        selectedFilterID = id
    }
}
