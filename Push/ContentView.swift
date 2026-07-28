//
//  ContentView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/28/26.
//

import SwiftUI
import MapKit
import UIKit

struct ContentView: View {
    @Environment(\.pushLayout) private var layout
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = MapViewModel()
    @StateObject private var alertsViewModel = AlertsViewModel()
    @State private var selectedNavigationItem: BottomNavigationItem = .map
    @State private var presentedRoute: MainMapRoute?
    @State private var isCreateMenuPresented = false
    @State private var isFilterDropdownExpanded = false
    @State private var selectedPuck: MapPuckData?
    @State private var selectedRegionalPuck: RegionalPuckModel?
    @State private var startPushContext: StartPushLaunchContext?
    @State private var mapSpan = MapDefaults.region.span
    @State private var forcedRenderSpan: MKCoordinateSpan?
    /// Skip the first `.active` after launch — bootstrap already warms the live store.
    @State private var hasEnteredBackground = false

    private var isPlansPresented: Bool {
        selectedNavigationItem == .plans
    }

    private var isFriendsPresented: Bool {
        selectedNavigationItem == .group
    }

    private var isFeedPresented: Bool {
        selectedNavigationItem == .feed
    }

    /// Friends/Feed/Pushes overlays hide map chrome and keep the shared bottom nav.
    private var isTabOverlayPresented: Bool {
        isPlansPresented || isFriendsPresented || isFeedPresented
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            StyledMapView(
                region: MapDefaults.region,
                pucks: viewModel.renderPucks(for: forcedRenderSpan ?? mapSpan),
                focusRequest: viewModel.mapFocusRequest,
                selectedRegionalPuckID: selectedRegionalPuck?.id,
                onPuckSelected: selectMapPuck,
                onMapTapped: dismissMapSelection,
                onRegionChanged: handleRegionChanged,
                layout: layout,
                mapLayoutMargins: MapAttributionLayout.edgeInsets(layout)
            )
            .ignoresSafeArea()

            if isFilterDropdownExpanded && !isTabOverlayPresented {
                filterDropdownBackdrop
                    .transition(.opacity)
            }

            if !isTabOverlayPresented,
               viewModel.surfacePhase == .empty || viewModel.surfacePhase == .failed {
                mapSurfaceOverlay
            }

            // Friends/Feed/Pushes stay under the map bottom nav (not fullScreenCovers)
            // so the floating bar keeps its position; + is contextual per tab.
            if isFriendsPresented {
                FriendsView(onLocateFriend: locateFriendOnMap)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .zIndex(TabOverlayLayout.zIndex)
            }

            if isFeedPresented {
                FeedDeferredView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .zIndex(TabOverlayLayout.zIndex)
            }

            if isPlansPresented {
                PlansView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .zIndex(TabOverlayLayout.zIndex)
            }

            if isCreateMenuPresented {
                createMenuBackdrop
                    .transition(.opacity)

                CreateActionMenuView(action: selectCreateAction)
                    .padding(.bottom, CreateActionMenuLayout.cardBottomPadding(layout))
                    .transition(
                        .move(edge: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: CreateActionMenuLayout.transitionScale, anchor: .bottom))
                    )
                    .zIndex(TabOverlayLayout.createMenuZIndex)
            }

            if !isTabOverlayPresented {
                VStack(spacing: 0) {
                    topControlsLayer
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zIndex(TopDropdownLayout.expandedZIndex)
            }

            BottomNavigationBar(
                selectedItem: $selectedNavigationItem,
                action: selectNavigationItem
            )
                .padding(.horizontal, BottomNavigationLayout.horizontalMargin(layout))
                .padding(.bottom, BottomNavigationLayout.bottomMargin(layout))
                .zIndex(TabOverlayLayout.bottomNavZIndex)

            if !isTabOverlayPresented, let selectedPuck {
                FriendDetailBottomSheet(
                    puck: selectedPuck,
                    onDismiss: dismissSelectedPuck,
                    onStartPush: launchStartPush
                )
            }

            if !isTabOverlayPresented, let selectedRegionalPuck {
                RegionalPuckDetailCard(
                    model: selectedRegionalPuck,
                    onZoomIn: { zoomIntoRegionalPuck(selectedRegionalPuck) }
                )
                .padding(.horizontal, RegionalPuckDetailLayout.horizontalPadding(layout))
                .padding(.bottom, RegionalPuckDetailLayout.bottomClearance(layout))
                .transition(
                    .move(edge: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .scale(scale: RegionalPuckDetailLayout.closedScale))
                )
                .zIndex(RegionalPuckDetailLayout.zIndex)
            }
        }
        .animation(
            .spring(response: CreateActionMenuLayout.animationResponse, dampingFraction: CreateActionMenuLayout.animationDamping),
            value: isCreateMenuPresented
        )
        .animation(.spring(response: TopDropdownLayout.animationResponse, dampingFraction: TopDropdownLayout.animationDamping), value: isFilterDropdownExpanded)
        .animation(PushMotion.sheet, value: selectedRegionalPuck?.id)
        .animation(.easeInOut(duration: TabOverlayLayout.transitionDuration), value: isTabOverlayPresented)
        .fullScreenCover(item: $presentedRoute) { route in
            destination(for: route)
        }
        .fullScreenCover(item: $startPushContext) { context in
            StartPushFlowView(context: context)
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhase(newPhase)
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            hasEnteredBackground = true
        case .active:
            guard hasEnteredBackground else { return }
            hasEnteredBackground = false
            // Foreground re-warm failures stay silent; pull-to-refresh can surface errors.
            Task { try? await AppDataContainer.shared.refreshSession() }
        default:
            break
        }
    }

    /// Lower-middle map card for empty/failed friend presence — below top controls and above bottom nav.
    /// Spacers pass hits through so the map stays pannable; only the card receives taps.
    private var mapSurfaceOverlay: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
                .allowsHitTesting(false)
            MapEmptyOverlay(
                phase: viewModel.surfacePhase,
                onAddFriends: {
                    isFilterDropdownExpanded = false
                    presentedRoute = .addFriend
                },
                onRetry: { Task { await viewModel.load() } }
            )
            .padding(.horizontal, MapEmptyOverlayLayout.horizontalPadding)
            .allowsHitTesting(true)
            Spacer()
                .frame(height: MapEmptyOverlayLayout.bottomClearance(layout))
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
    }

    private var topControlsLayer: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .center, spacing: 0) {
                TopIconButton(
                    systemImageName: MainMapRoute.profile.systemImageName,
                    accessibilityLabel: MainMapRoute.profile.accessibilityLabel
                ) {
                    isFilterDropdownExpanded = false
                    presentedRoute = .profile
                }

                Spacer(minLength: 0)

                FriendGroupDropdownButton(
                    selectedTitle: viewModel.selectedFilterTitle,
                    isExpanded: isFilterDropdownExpanded
                ) {
                    isCreateMenuPresented = false
                    isFilterDropdownExpanded.toggle()
                }
                .frame(width: TopControlLayout.dropdownWidth(layout))

                Spacer(minLength: 0)

                TopIconButton(
                    systemImageName: MainMapRoute.alerts.systemImageName,
                    accessibilityLabel: MainMapRoute.alerts.accessibilityLabel,
                    showsIndicator: alertsViewModel.hasUnreadAlerts
                ) {
                    isFilterDropdownExpanded = false
                    presentedRoute = .alerts
                }
            }
            .padding(.horizontal, TopControlLayout.horizontalMargin(layout))
            .padding(.top, TopControlLayout.topMargin)

            if isFilterDropdownExpanded {
                FriendGroupDropdownPanel(
                    items: viewModel.filters,
                    selectedID: viewModel.selectedFilterID,
                    select: selectFilter
                )
                .padding(.top, TopControlLayout.topMargin + TopControlLayout.dropdownHeight + TopDropdownLayout.panelSpacing)
                .transition(
                    .opacity
                        .combined(with: .scale(scale: TopDropdownLayout.panelTransitionScale, anchor: .top))
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(
            height: isFilterDropdownExpanded ? TopDropdownLayout.overlayHeight : TopDropdownLayout.collapsedOverlayHeight,
            alignment: .top
        )
    }

    private func selectNavigationItem(_ item: BottomNavigationItem) {
        isFilterDropdownExpanded = false

        if item == .create {
            // Contextual +: skip the create menu on tab overlays.
            if selectedNavigationItem == .plans {
                isCreateMenuPresented = false
                startPushContext = .blank
                return
            }
            if selectedNavigationItem == .group {
                isCreateMenuPresented = false
                presentedRoute = .addFriend
                return
            }
            isCreateMenuPresented.toggle()
            return
        }

        isCreateMenuPresented = false

        if item == .group {
            selectedPuck = nil
            selectedRegionalPuck = nil
            selectedNavigationItem = .group
            return
        }

        if item == .feed {
            selectedPuck = nil
            selectedRegionalPuck = nil
            selectedNavigationItem = .feed
            return
        }

        if item == .plans {
            selectedPuck = nil
            selectedRegionalPuck = nil
            selectedNavigationItem = .plans
            return
        }

        selectedNavigationItem = item
    }

    @ViewBuilder
    private func destination(for route: MainMapRoute) -> some View {
        switch route {
        case .groups:
            // Friends is embedded under the bottom nav; keep a destination for
            // any residual MainMapRoute.groups presentation.
            FriendsView(onLocateFriend: locateFriendOnMap)
        case .profile:
            ProfileView {
                presentedRoute = nil
            }
        case .alerts:
            AlertsView(viewModel: alertsViewModel)
        case .startPlan:
            StartPushFlowView()
        case .addFriend:
            AddFriendsView()
        case .feed:
            // Feed is embedded under the bottom nav; keep a destination for
            // any residual MainMapRoute.feed presentation.
            FeedDeferredView()
        case .plans:
            // Pushes is embedded under the bottom nav; keep a destination for
            // any residual MainMapRoute.plans presentation.
            PlansView()
        case .startPush:
            StartPushFlowView()
        }
    }

    private var createMenuBackdrop: some View {
        Color.black
            .opacity(CreateActionMenuLayout.backdropOpacity)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                isCreateMenuPresented = false
            }
    }

    /// Invisible tap-catcher over the map so tapping outside the panel closes
    /// it — mirrors `createMenuBackdrop`'s interception technique, but stays
    /// transparent since this control doesn't need to dim the map.
    private var filterDropdownBackdrop: some View {
        Color.clear
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .onTapGesture {
                isFilterDropdownExpanded = false
            }
    }

    private func selectCreateAction(_ item: CreateActionMenuItem) {
        isCreateMenuPresented = false
        isFilterDropdownExpanded = false
        selectedNavigationItem = .map
        presentedRoute = item.route
    }

    private func selectMapPuck(_ puck: MapPuckRenderModel) {
        isFilterDropdownExpanded = false
        if case .regionalCluster(let regional) = puck {
            selectedPuck = nil
            selectedRegionalPuck = regional
            return
        }
        selectedRegionalPuck = nil
        if let selected = viewModel.select(puck) {
            presentSelectedPuck(selected)
        }
    }

    private func zoomIntoRegionalPuck(_ puck: RegionalPuckModel) {
        selectedRegionalPuck = nil
        viewModel.focus(on: puck)
        guard let focusRequest = viewModel.mapFocusRequest else { return }
        forcedRenderSpan = focusRequest.region.span
        mapSpan = focusRequest.region.span
    }

    private func dismissMapSelection() {
        selectedRegionalPuck = nil
    }

    private func locateFriendOnMap(_ personID: Person.ID) -> Bool {
        guard let puck = viewModel.select(personID: personID) else { return false }
        isFilterDropdownExpanded = false
        forcedRenderSpan = viewModel.mapFocusRequest?.region.span
        if let span = forcedRenderSpan {
            mapSpan = span
        }
        presentSelectedPuck(puck)
        presentedRoute = nil
        // Avatar-locate leaves the Friends tab overlay for the map.
        selectedNavigationItem = .map
        return true
    }

    private func presentSelectedPuck(_ puck: MapPuckData) {
        // Sheet owns its slide animation (offset), so identity changes stay
        // unanimated — otherwise glass hangout actions paint before the chrome.
        selectedPuck = puck
    }

    private func dismissSelectedPuck() {
        selectedPuck = nil
    }

    private func launchStartPush(_ context: StartPushLaunchContext) {
        // FriendDetailBottomSheet already animated out and cleared selection
        // before invoking this callback.
        startPushContext = context
    }

    private func handleRegionChanged(_ span: MKCoordinateSpan) {
        mapSpan = span
        if span.latitudeDelta <= MapDefaults.closeRegionalLatitudeDelta {
            forcedRenderSpan = nil
        }
    }

    private func selectFilter(_ item: GroupFilterItem) {
        guard viewModel.selectedFilterID != item.id else {
            isFilterDropdownExpanded = false
            return
        }
        viewModel.selectedFilterID = item.id
        isFilterDropdownExpanded = false
    }
}

private enum RegionalPuckDetailLayout {
    static func horizontalPadding(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.pageHorizontalPadding
    }

    static func bottomClearance(_ layout: PushAdaptiveLayout) -> CGFloat {
        layout.value(compact: 96, standard: 104, large: 112)
    }

    static let closedScale = PushMotion.Sheet.closedScale
    static let zIndex: Double = 28
}

private enum TabOverlayLayout {
    /// Above map chrome; below create menu and bottom nav.
    static let zIndex: Double = 5
    static let createMenuZIndex: Double = 15
    static let bottomNavZIndex: Double = 20
    static let transitionDuration: Double = 0.2
}

private struct FriendGroupDropdownButton: View {
    let selectedTitle: String
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TopDropdownLayout.labelSpacing) {
                Text(selectedTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.activeForeground)

                Image(systemName: "chevron.down")
                    .font(.system(size: TopDropdownLayout.chevronSize, weight: .bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                    .rotationEffect(.degrees(isExpanded ? TopDropdownLayout.expandedChevronRotation : 0))
            }
            .frame(maxWidth: .infinity)
            .frame(height: TopControlLayout.dropdownHeight)
            .lineLimit(1)
            .minimumScaleFactor(TopControlLayout.minimumTextScale)
            .padding(.horizontal, TopDropdownLayout.horizontalPadding)
            .topControlBackground(cornerRadius: TopControlLayout.cornerRadius, treatment: .filterPill)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel("Friend group")
        .accessibilityValue(selectedTitle)
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
    }
}

private struct FriendGroupDropdownPanel: View {
    @Environment(\.pushLayout) private var layout
    let items: [GroupFilterItem]
    let selectedID: String
    let select: (GroupFilterItem) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: TopDropdownLayout.rowSpacing) {
                ForEach(items) { item in
                    Button {
                        select(item)
                    } label: {
                        FriendGroupDropdownRow(
                            item: item,
                            isSelected: selectedID == item.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedID == item.id ? .isSelected : [])
                }
            }
            .padding(TopDropdownLayout.panelPadding)
        }
        .frame(width: TopDropdownLayout.panelWidth(layout))
        .frame(maxHeight: TopDropdownLayout.panelMaxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .topControlBackground(cornerRadius: TopDropdownLayout.panelCornerRadius)
    }
}

private struct FriendGroupDropdownRow: View {
    let item: GroupFilterItem
    let isSelected: Bool

    var body: some View {
        PushSingleSelectRow(title: item.title, isSelected: isSelected)
    }
}

private struct TopIconButton: View {
    let systemImageName: String
    let accessibilityLabel: String
    var showsIndicator = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImageName)
                .font(.system(size: TopControlLayout.iconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(width: TopControlLayout.iconButtonSize, height: TopControlLayout.iconButtonSize)
                .topControlBackground(cornerRadius: TopControlLayout.cornerRadius, treatment: .profileButton)
                .overlay(alignment: .topTrailing) {
                    if showsIndicator {
                        Circle()
                            .fill(PushControlColors.activeFill)
                            .frame(width: TopControlLayout.indicatorSize, height: TopControlLayout.indicatorSize)
                            .overlay {
                                Circle().stroke(
                                    PushControlColors.activeForeground,
                                    lineWidth: TopControlLayout.indicatorStrokeWidth
                                )
                            }
                            .padding(TopControlLayout.indicatorInset)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private extension View {
    /// Map top chrome — prefers DesignSystem `pushMapControlGlass` (DS-011).
    func topControlBackground(
        cornerRadius: CGFloat,
        treatment: PushMapControlTreatment = .standard
    ) -> some View {
        pushMapControlGlass(cornerRadius: cornerRadius, treatment: treatment)
    }
}

private enum MapDefaults {
    static let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        ),
        span: MKCoordinateSpan(
            latitudeDelta: latitudeDelta,
            longitudeDelta: longitudeDelta
        )
    )

    private static let latitude = 37.7749
    private static let longitude = -122.4194
    private static let latitudeDelta = 0.08
    private static let longitudeDelta = 0.08
    static let closeRegionalLatitudeDelta = 0.22
}

private enum TopDropdownLayout {
    static let collapsedOverlayHeight = TopControlLayout.topMargin + TopControlLayout.dropdownHeight
    static let overlayHeight: CGFloat = 340
    static let horizontalPadding: CGFloat = 18
    static let labelSpacing: CGFloat = 6
    static let panelSpacing: CGFloat = 8
    static let panelPadding: CGFloat = 6
    static func panelWidth(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 196, standard: 208, large: 218) }
    /// Caps the panel at ~5 visible rows before it scrolls; eyeballed against
    /// current row metrics, same convention as `overlayHeight`/`dropdownHeight`.
    static let panelMaxHeight: CGFloat = 240
    static let panelCornerRadius: CGFloat = 24
    static let rowSpacing: CGFloat = 2
    static let chevronSize: CGFloat = 11
    static let expandedChevronRotation = 180.0
    static let panelTransitionScale = 0.96
    static let animationResponse = 0.28
    static let animationDamping = 0.86
    static let expandedZIndex = 1.0
}

private enum TopControlLayout {
    static let topMargin: CGFloat = 10
    static func horizontalMargin(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 12, standard: 14, large: 16) }
    static func dropdownWidth(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 124, standard: 132, large: 139.4) }
    static let dropdownHeight: CGFloat = 46
    static let iconButtonSize: CGFloat = 44
    static let cornerRadius: CGFloat = iconButtonSize / 2
    static let iconSize: CGFloat = 17
    static let indicatorSize: CGFloat = 10
    static let indicatorStrokeWidth: CGFloat = 1
    /// Insets the unread badge from the control edge so it sits on the icon, not outside the button.
    static let indicatorInset: CGFloat = 9
    static let minimumTextScale = 0.78
}

private enum MapAttributionLayout {
    // Insets tell MapKit where to place the Apple logo and legal text.
    // Keep attribution low and discreet, visually below the floating bottom nav.
    static func top(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 104, standard: 112, large: 120) }
    static func bottom(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 12, standard: 14, large: 16) }
    static let left: CGFloat = 16
    static let right: CGFloat = 16

    static func edgeInsets(_ layout: PushAdaptiveLayout) -> UIEdgeInsets {
        UIEdgeInsets(top: top(layout), left: left, bottom: bottom(layout), right: right)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            ContentView()
        }
    }
}
#endif
