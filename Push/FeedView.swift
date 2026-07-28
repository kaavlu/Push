//
//  FeedView.swift
//  Push
//
//  Structural Feed shell (Issue #9): header, Pushes/Now segments, filter chips,
//  and polished placeholders. No Push cards or live activity yet.
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

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: FeedLayout.chipToContentSpacing) {
                        FeedFilterChips(viewModel: viewModel)
                        tabContent
                    }
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
            FeedPushesPlaceholder()
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

// MARK: - Placeholders

private struct FeedPushesPlaceholder: View {
    @Environment(\.pushLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: FeedLayout.placeholderCardSpacing) {
            Text(EmptySurfaceCopy.feedPushesPlaceholderTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)
            Text(EmptySurfaceCopy.feedPushesPlaceholderMessage)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: FeedLayout.placeholderCardMinHeight, alignment: .topLeading)
        .padding(FeedLayout.placeholderCardPadding)
        .pushSolidCreamCard(cornerRadius: layout.cardCornerRadius)
        .accessibilityElement(children: .combine)
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
#endif
