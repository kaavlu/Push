//
//  FriendsComponents.swift
//  Push
//
//  Shared, screen-local building blocks for the Friends screen: the glass
//  circle button, the availability chip, the compact group card, and the empty
//  state.
//

import SwiftUI

// Ivory page + solid cream card live in DesignSystem (PushCreamSurfaces).
// FriendsAvailabilityChip → PushAvailabilityChip (DesignSystem).

// MARK: - Filter Chips (DS-036)

struct FriendsFilterChipRow: View {
    @Binding var selected: FriendsFilter
    let counts: [FriendsFilter: Int]

    private var selectedID: Binding<String> {
        Binding(
            get: { selected.rawValue },
            set: { selected = FriendsFilter(rawValue: $0) ?? .all }
        )
    }

    private var items: [PushIvoryFilterItem] {
        FriendsFilter.allCases.map { filter in
            PushIvoryFilterItem(
                id: filter.rawValue,
                title: filter.title,
                count: counts[filter] ?? 0
            )
        }
    }

    var body: some View {
        PushIvoryFilterChipRow(items: items, selectedID: selectedID)
    }
}

// Section header → PushListSectionHeader (FriendsSectionHeader typealias).
// Group card → PushGroupRow (FriendGroupCard typealias).

// Empty state → FriendsEmptyState in DesignSystem EmptyStates (DS-071).
