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
    @State private var addYoursContext: AddYoursContext?
    /// Participant card … → edit that moment in Create Post compose.
    @State private var editMomentCarousel: FeedMediaCarouselData?

    @MainActor
    init(viewModel: FeedViewModel? = nil) {
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
                PushCreamPageHeader(title: "Feed")
                FeedTabSwitch(viewModel: viewModel)
                // Group filters stay pinned under the segment (do not scroll away).
                FeedFilterChips(viewModel: viewModel)

                ScrollView(showsIndicators: false) {
                    tabContent
                        .padding(.top, FeedLayout.chipToContentSpacing)
                        .padding(.bottom, FeedLayout.contentBottomClearance(layout))
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .padding(.horizontal, FeedLayout.horizontalPadding(layout))
            .padding(.top, FeedLayout.topPadding)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let actionError = viewModel.actionError {
                ActionErrorBanner(
                    message: actionError.message,
                    onRetry: { Task { await viewModel.retryLoadMore() } },
                    onDismiss: { viewModel.dismissActionError() }
                )
                .padding(.horizontal, FeedLayout.horizontalPadding(layout))
                .padding(.bottom, FeedLayout.contentBottomClearance(layout))
            }
        }
        .fullScreenCover(item: $addYoursContext) { context in
            AddYoursView(context: context)
        }
        .fullScreenCover(item: $editMomentCarousel) { carousel in
            CreatePostFlowView(
                viewModel: CreatePostViewModel.forEditingFeedMoment(carousel)
            )
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .pushes:
            pushesContent
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

    /// Moment stream states (DS-070/071). Content stays on screen while a
    /// refresh or an incremental page is in flight.
    @ViewBuilder
    private var pushesContent: some View {
        switch viewModel.contentPhase {
        case .loading, .deferred:
            EmptySurfaceStateView.loading
                .frame(minHeight: FeedLayout.statePlaceholderMinHeight)
        case .failed:
            EmptySurfaceStateView.failed(surface: MomentFeedCopy.surfaceName) {
                Task { await viewModel.load() }
            }
            .frame(minHeight: FeedLayout.statePlaceholderMinHeight)
        case .empty:
            EmptySurfaceView(
                title: MomentFeedCopy.emptyTitle,
                message: viewModel.selectedFilterID == MomentFeedFilter.allID
                    ? MomentFeedCopy.emptyMessage
                    : MomentFeedCopy.emptyGroupMessage,
                systemImage: "rectangle.stack"
            )
            .frame(maxWidth: .infinity)
            .padding(.top, EmptySurfaceLayout.topPadding)
        case .content:
            FeedPushesMediaStack(
                carousels: viewModel.mediaCarousels,
                isLoadingMore: viewModel.isLoadingMore,
                onAddYours: { carousel in
                    addYoursContext = AddYoursContext(carousel: carousel)
                },
                onEditMoment: { carousel in
                    editMomentCarousel = carousel
                },
                onCardAppear: { carousel in
                    Task { await viewModel.loadMoreIfNeeded(after: carousel.id) }
                }
            )
        }
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
    var isLoadingMore = false
    var onAddYours: (FeedMediaCarouselData) -> Void = { _ in }
    var onEditMoment: (FeedMediaCarouselData) -> Void = { _ in }
    /// Fires per card so the last one can request the next keyset page.
    var onCardAppear: (FeedMediaCarouselData) -> Void = { _ in }

    var body: some View {
        LazyVStack(spacing: FeedLayout.mediaStackSpacing) {
            ForEach(carousels) { carousel in
                PushMediaCarousel(
                    data: carousel,
                    onOverflowMenu: { onEditMoment(carousel) },
                    onAddYours: { onAddYours(carousel) }
                )
                .onAppear { onCardAppear(carousel) }
            }

            if isLoadingMore {
                ProgressView()
                    .tint(PushControlColors.activeForeground)
                    .padding(.vertical, FeedLayout.loadMoreSpinnerPadding)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            // Fixture seam — the app path always loads from `MomentRepository`.
            FeedView(
                viewModel: FeedViewModel(
                    carousels: FeedMediaCarouselFixtures.feedPushesPreviewStack,
                    filterItems: FeedFilterFixtures.items
                )
            )
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
