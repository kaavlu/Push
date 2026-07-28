//
//  FeedView.swift
//  Push
//
//  Feed shell (Issue #9): header, Pushes/Now segments, filter chips, and
//  media-carousel foundation on Pushes. Full Push-card chrome comes later.
//  Embedded under ContentView's bottom nav; leave via the shared tab bar.
//

import SwiftUI

struct FeedView: View {
    @Environment(\.pushLayout) private var layout
    @StateObject private var viewModel: FeedViewModel
    let hasUnreadAlerts: Bool
    let onOpenAlerts: () -> Void
    /// Filter/settings is structural only this issue — intentionally no-op.
    var onFilterSettings: () -> Void = {}

    @MainActor
    init(
        hasUnreadAlerts: Bool = false,
        onOpenAlerts: @escaping () -> Void = {},
        onFilterSettings: @escaping () -> Void = {},
        viewModel: FeedViewModel? = nil
    ) {
        self.hasUnreadAlerts = hasUnreadAlerts
        self.onOpenAlerts = onOpenAlerts
        self.onFilterSettings = onFilterSettings
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: FeedViewModel())
        }
    }

    var body: some View {
        ZStack {
            FriendsBackground()

            VStack(spacing: FeedLayout.screenStackSpacing(layout)) {
                FeedPageHeader(
                    hasUnreadAlerts: hasUnreadAlerts,
                    onFilterSettings: onFilterSettings,
                    onOpenAlerts: onOpenAlerts
                )
                FeedTabSwitch(viewModel: viewModel)
                // Group filters stay pinned under the segment (do not scroll away).
                FeedFilterChips(viewModel: viewModel)

                ScrollView(showsIndicators: false) {
                    tabContent
                        .padding(.top, FeedLayout.chipToContentSpacing)
                        .padding(.bottom, FeedLayout.contentBottomClearance(layout))
                }
            }
            .padding(.horizontal, FeedLayout.horizontalPadding(layout))
            .padding(.top, FeedLayout.topPadding)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .pushes:
            FeedPushesMediaStack(carousels: viewModel.mediaCarousels)
        case .now:
            EmptySurfaceView(
                title: EmptySurfaceCopy.feedNowEmptyTitle,
                message: EmptySurfaceCopy.feedNowEmptyMessage,
                systemImage: "sparkles"
            )
            .frame(maxWidth: .infinity)
            .padding(.top, EmptySurfaceLayout.topPadding)
        }
    }
}

// MARK: - Header

private struct FeedPageHeader: View {
    let hasUnreadAlerts: Bool
    let onFilterSettings: () -> Void
    let onOpenAlerts: () -> Void

    var body: some View {
        PushCreamPageHeader(title: "Feed") {
            HStack(spacing: FeedLayout.headerActionSpacing) {
                PushCircleIconButton(
                    systemImageName: "slider.horizontal.3",
                    accessibilityLabel: "Feed filter settings",
                    action: onFilterSettings
                )
                FeedAlertsButton(
                    hasUnreadAlerts: hasUnreadAlerts,
                    action: onOpenAlerts
                )
            }
        }
    }
}

private struct FeedAlertsButton: View {
    let hasUnreadAlerts: Bool
    let action: () -> Void

    var body: some View {
        PushCircleIconButton(
            systemImageName: MainMapRoute.alerts.systemImageName,
            accessibilityLabel: MainMapRoute.alerts.accessibilityLabel,
            action: action
        )
        .overlay(alignment: .topTrailing) {
            if hasUnreadAlerts {
                Circle()
                    .fill(PushControlColors.activeFill)
                    .frame(
                        width: FeedLayout.alertIndicatorSize,
                        height: FeedLayout.alertIndicatorSize
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                PushControlColors.activeForeground,
                                lineWidth: FeedLayout.alertIndicatorStrokeWidth
                            )
                    }
                    .padding(FeedLayout.alertIndicatorInset)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityValue(hasUnreadAlerts ? "Unread alerts" : "No unread alerts")
    }
}

// MARK: - Segment + filters

private struct FeedTabSwitch: View {
    @ObservedObject var viewModel: FeedViewModel

    private var selectedID: Binding<String> {
        Binding(
            get: { viewModel.selectedTab.rawValue },
            set: { viewModel.selectedTab = FeedTab(rawValue: $0) ?? .pushes }
        )
    }

    private var items: [PushIvorySegmentedItem] {
        FeedTab.allCases.map { tab in
            PushIvorySegmentedItem(id: tab.rawValue, title: tab.title)
        }
    }

    var body: some View {
        PushIvorySegmentedControl(items: items, selectedID: selectedID)
    }
}

private struct FeedFilterChips: View {
    @ObservedObject var viewModel: FeedViewModel

    private var selectedID: Binding<String> {
        Binding(
            get: { viewModel.selectedFilterID },
            set: { viewModel.selectFilter(id: $0) }
        )
    }

    var body: some View {
        PushIvoryFilterChipRow(items: viewModel.filterItems, selectedID: selectedID)
    }
}

// MARK: - Pushes media stack

private struct FeedPushesMediaStack: View {
    let carousels: [FeedMediaCarouselData]

    var body: some View {
        if carousels.isEmpty {
            EmptySurfaceView(
                title: EmptySurfaceCopy.feedPushesPlaceholderTitle,
                message: EmptySurfaceCopy.feedPushesPlaceholderMessage,
                systemImage: "rectangle.stack"
            )
            .frame(maxWidth: .infinity)
            .padding(.top, EmptySurfaceLayout.topPadding)
        } else {
            VStack(spacing: FeedLayout.mediaStackSpacing) {
                ForEach(carousels) { carousel in
                    PushMediaCarousel(data: carousel)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#if DEBUG
struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            FeedView(hasUnreadAlerts: true)
        }
    }
}

struct FeedMediaCarouselFixtures_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(FeedMediaCarouselFixtures.feedPushesPreviewStack) { data in
                        PushMediaCarousel(data: data)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(PushIvoryPageBackground())
        }
    }
}
#endif
