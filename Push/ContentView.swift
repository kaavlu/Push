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
    @State private var startPushContext: StartPushLaunchContext?
    @State private var mapSpan = MapDefaults.region.span
    @State private var forcedRenderSpan: MKCoordinateSpan?
    /// Skip the first `.active` after launch — bootstrap already warms the live store.
    @State private var hasEnteredBackground = false

    var body: some View {
        ZStack(alignment: .bottom) {
            StyledMapView(
                region: MapDefaults.region,
                pucks: viewModel.renderPucks(for: forcedRenderSpan ?? mapSpan),
                focusRequest: viewModel.mapFocusRequest,
                onPuckSelected: selectMapPuck,
                onRegionChanged: handleRegionChanged,
                layout: layout,
                mapLayoutMargins: MapAttributionLayout.edgeInsets(layout)
            )
            .ignoresSafeArea()

            if viewModel.surfacePhase == .empty || viewModel.surfacePhase == .failed {
                mapSurfaceOverlay
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
            }

            VStack(spacing: 0) {
                topControlsLayer
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .zIndex(TopDropdownLayout.expandedZIndex)

            BottomNavigationBar(
                selectedItem: $selectedNavigationItem,
                action: selectNavigationItem
            )
                .padding(.horizontal, BottomNavigationLayout.horizontalMargin(layout))
                .padding(.bottom, BottomNavigationLayout.bottomMargin(layout))

            if let selectedPuck {
                FriendDetailBottomSheet(
                    puck: selectedPuck,
                    onDismiss: dismissSelectedPuck,
                    onStartPush: launchStartPush
                )
            }
        }
        .animation(
            .spring(response: CreateActionMenuLayout.animationResponse, dampingFraction: CreateActionMenuLayout.animationDamping),
            value: isCreateMenuPresented
        )
        .animation(.spring(response: TopDropdownLayout.animationResponse, dampingFraction: TopDropdownLayout.animationDamping), value: isFilterDropdownExpanded)
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
            isCreateMenuPresented.toggle()
            return
        }

        isCreateMenuPresented = false

        if item == .group {
            selectedNavigationItem = .map
            presentedRoute = .groups
            return
        }

        if item == .feed {
            selectedNavigationItem = .map
            presentedRoute = .feed
            return
        }

        if item == .plans {
            selectedNavigationItem = .map
            presentedRoute = .plans
            return
        }

        selectedNavigationItem = item
    }

    @ViewBuilder
    private func destination(for route: MainMapRoute) -> some View {
        switch route {
        case .groups:
            FriendsView()
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
            FeedDeferredView()
        case .plans:
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

    private func selectCreateAction(_ item: CreateActionMenuItem) {
        isCreateMenuPresented = false
        isFilterDropdownExpanded = false
        selectedNavigationItem = .map
        presentedRoute = item.route
    }

    private func selectMapPuck(_ puck: MapPuckRenderModel) {
        isFilterDropdownExpanded = false
        if let selected = viewModel.select(puck) {
            presentSelectedPuck(selected)
        } else if let focusRequest = viewModel.mapFocusRequest {
            forcedRenderSpan = focusRequest.region.span
            mapSpan = focusRequest.region.span
        }
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
    }
}

private struct FriendGroupDropdownPanel: View {
    @Environment(\.pushLayout) private var layout
    let items: [GroupFilterItem]
    let selectedID: String
    let select: (GroupFilterItem) -> Void

    var body: some View {
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
            }
        }
        .padding(TopDropdownLayout.panelPadding)
        .frame(width: TopDropdownLayout.panelWidth(layout))
        .topControlBackground(cornerRadius: TopDropdownLayout.panelCornerRadius)
    }
}

private struct FriendGroupDropdownRow: View {
    let item: GroupFilterItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: TopDropdownLayout.rowIconSpacing) {
            Text(item.title)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? PushControlColors.activeForeground : PushControlColors.inactiveForeground)

            Spacer(minLength: 0)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: TopDropdownLayout.checkmarkSize, weight: .bold))
                    .foregroundStyle(PushControlColors.activeForeground)
            }
        }
        .padding(.horizontal, TopDropdownLayout.rowHorizontalPadding)
        .padding(.vertical, TopDropdownLayout.rowVerticalPadding)
        .background(rowBackground)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            Capsule()
                .fill(PushControlColors.activeFill)
        }
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
    func topControlBackground(
        cornerRadius: CGFloat,
        treatment: TopControlTreatment = .standard
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(.ultraThinMaterial, in: shape)
            .background(shape.fill(TopControlColor.fill))
            .background(shape.fill(treatment.centerHighlight))
            .overlay {
                shape
                    .fill(treatment.surfaceGlow)
                    .clipShape(shape)
            }
            .overlay {
                shape.stroke(
                    treatment.outerStroke,
                    lineWidth: treatment.strokeWidth
                )
            }
            .overlay {
                shape
                    .stroke(treatment.reflectiveHighlight, lineWidth: TopControlLayout.highlightWidth)
                    .padding(TopControlLayout.highlightInset)
            }
            .shadow(
                color: TopControlColor.shadow,
                radius: TopControlLayout.shadowRadius,
                y: TopControlLayout.shadowYOffset
            )
    }
}

private enum TopControlTreatment {
    case standard
    case filterPill
    case profileButton

    var centerHighlight: AnyShapeStyle {
        switch self {
        case .profileButton:
            return AnyShapeStyle(Color.white.opacity(TopControlColor.profileCenterOpacity))
        case .standard, .filterPill:
            return AnyShapeStyle(Color.clear)
        }
    }

    var surfaceGlow: AnyShapeStyle {
        switch self {
        case .filterPill:
            return AnyShapeStyle(RadialGradient(
                colors: [
                    PushGlassStyle.warmTint.opacity(TopControlColor.pillCreamGlowOpacity),
                    PushControlColors.activeFill.opacity(TopControlColor.pillGlowOpacity),
                    .clear
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: TopControlLayout.pillGlowRadius
            ))
        case .profileButton:
            return AnyShapeStyle(RadialGradient(
                colors: [
                    Color.white.opacity(TopControlColor.profileCoreOpacity),
                    PushGlassStyle.warmTint.opacity(TopControlColor.profileCreamGlowOpacity),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: TopControlLayout.profileGlowRadius
            ))
        case .standard:
            return AnyShapeStyle(Color.clear)
        }
    }

    var outerStroke: AnyShapeStyle {
        switch self {
        case .profileButton:
            return AnyShapeStyle(PushControlColors.activeFill.opacity(TopControlColor.profileRingOpacity))
        case .standard, .filterPill:
            return AnyShapeStyle(TopControlColor.stroke)
        }
    }

    var reflectiveHighlight: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(
            colors: [
                Color.white.opacity(highlightTopOpacity),
                Color.white.opacity(TopControlColor.highlightSideOpacity),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        ))
    }

    var strokeWidth: CGFloat {
        self == .profileButton ? TopControlLayout.profileRingWidth : TopControlLayout.strokeWidth
    }

    private var highlightTopOpacity: Double {
        self == .filterPill ? TopControlColor.pillHighlightOpacity : TopControlColor.highlightOpacity
    }
}

private enum TopControlColor {
    static let fill = PushGlassStyle.warmTint.opacity(0.38)
    static let stroke = Color.white.opacity(PushGlassStyle.strokeOpacity)
    static let shadow = PushGlassStyle.shadowColor.opacity(PushGlassStyle.shadowOpacity)
    static let pillCreamGlowOpacity = 0.28
    static let pillGlowOpacity = 0.18
    static let pillHighlightOpacity = 0.84
    static let profileRingOpacity = 0.52
    static let profileCenterOpacity = 0.16
    static let profileCoreOpacity = 0.26
    static let profileCreamGlowOpacity = 0.20
    static let highlightOpacity = 0.72
    static let highlightSideOpacity = 0.14
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
    static let panelCornerRadius: CGFloat = 24
    static let rowSpacing: CGFloat = 2
    static let rowHorizontalPadding: CGFloat = 12
    static let rowVerticalPadding: CGFloat = 10
    static let rowIconSpacing: CGFloat = 8
    static let chevronSize: CGFloat = 11
    static let checkmarkSize: CGFloat = 12
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
    static let strokeWidth: CGFloat = 1
    static let profileRingWidth: CGFloat = 1.15
    static let highlightWidth: CGFloat = 0.8
    static let highlightInset: CGFloat = 1.2
    static let pillGlowRadius: CGFloat = 58
    static let profileGlowRadius: CGFloat = 24
    static let shadowRadius: CGFloat = 22
    static let shadowYOffset: CGFloat = 10
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
