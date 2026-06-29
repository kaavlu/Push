//
//  ContentView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/28/26.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @State private var selectedNavigationItem: BottomNavigationItem = .map
    @State private var selectedFriendGroup: FriendGroupFilter = .allFriends
    @State private var presentedRoute: MainMapRoute?
    @State private var isCreateMenuPresented = false

    var body: some View {
        ZStack(alignment: .bottom) {
            StyledMapView(region: MapDefaults.region, pucks: MapPuckMockData.pucks)
                .ignoresSafeArea()

            if isCreateMenuPresented {
                createMenuBackdrop
                    .transition(.opacity)

                CreateActionMenuView(action: selectCreateAction)
                    .padding(.bottom, CreateActionMenuLayout.cardBottomPadding)
                    .transition(
                        .move(edge: .bottom)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: CreateActionMenuLayout.transitionScale, anchor: .bottom))
                    )
            }

            BottomNavigationBar(
                selectedItem: $selectedNavigationItem,
                action: selectNavigationItem
            )
                .padding(.horizontal, BottomNavigationLayout.horizontalMargin)
                .padding(.bottom, BottomNavigationLayout.bottomMargin)
        }
        .animation(
            .spring(response: CreateActionMenuLayout.animationResponse, dampingFraction: CreateActionMenuLayout.animationDamping),
            value: isCreateMenuPresented
        )
        .overlay(alignment: .top) {
            HStack(alignment: .center, spacing: 0) {
                TopIconButton(systemImageName: "bell.fill", accessibilityLabel: "Notifications") {
                }

                Spacer(minLength: 0)

                FriendGroupDropdown(selectedGroup: $selectedFriendGroup)
                    .frame(width: TopControlLayout.dropdownWidth)

                Spacer(minLength: 0)

                TopIconButton(
                    systemImageName: MainMapRoute.profile.systemImageName,
                    accessibilityLabel: MainMapRoute.profile.accessibilityLabel
                ) {
                    presentedRoute = .profile
                }
            }
            .padding(.horizontal, TopControlLayout.horizontalMargin)
            .padding(.top, TopControlLayout.topMargin)
        }
        .fullScreenCover(item: $presentedRoute) { route in
            destination(for: route)
        }
    }

    private func selectNavigationItem(_ item: BottomNavigationItem) {
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
            GroupsView()
        case .profile:
            ProfileView()
        case .startPlan:
            CreatePlaceholderView(
                title: "Start Plan",
                subtitle: "Create a plan with friends.",
                symbolName: route.systemImageName
            )
        case .addFriend:
            CreatePlaceholderView(
                title: "Add Friend",
                subtitle: "Invite someone to Push.",
                symbolName: route.systemImageName
            )
        case .feed:
            CreatePlaceholderView(
                title: "Feed",
                subtitle: "What's happening with your friends.",
                symbolName: route.systemImageName
            )
        case .plans:
            CreatePlaceholderView(
                title: "Plans",
                subtitle: "Shared plans with your people.",
                symbolName: route.systemImageName
            )
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
        selectedNavigationItem = .map
        presentedRoute = item.route
    }
}

private struct FriendGroupDropdown: View {
    @Binding var selectedGroup: FriendGroupFilter
    @State private var isExpanded = false

    var body: some View {
        dropdownButton
            .overlay(alignment: .top) {
            if isExpanded {
                dropdownPanel
                    .padding(.top, TopControlLayout.dropdownHeight + TopDropdownLayout.panelSpacing)
                    .transition(
                        .move(edge: .top)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: TopDropdownLayout.panelTransitionScale, anchor: .top))
                    )
            }
        }
        .animation(.spring(response: TopDropdownLayout.animationResponse, dampingFraction: TopDropdownLayout.animationDamping), value: isExpanded)
        .zIndex(TopDropdownLayout.expandedZIndex)
    }

    private var dropdownButton: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: TopDropdownLayout.labelSpacing) {
                Text(selectedGroup.title)
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
            .pushGlassBackground(cornerRadius: TopControlLayout.cornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Friend group")
        .accessibilityValue(selectedGroup.title)
    }

    private var dropdownPanel: some View {
        VStack(spacing: TopDropdownLayout.rowSpacing) {
            ForEach(FriendGroupFilter.allCases) { group in
                Button {
                    select(group)
                } label: {
                    FriendGroupDropdownRow(
                        group: group,
                        isSelected: selectedGroup == group
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(TopDropdownLayout.panelPadding)
        .frame(width: TopDropdownLayout.panelWidth)
        .pushGlassBackground(cornerRadius: TopDropdownLayout.panelCornerRadius)
    }

    private func select(_ group: FriendGroupFilter) {
        selectedGroup = group
        isExpanded = false
    }
}

private struct FriendGroupDropdownRow: View {
    let group: FriendGroupFilter
    let isSelected: Bool

    var body: some View {
        HStack(spacing: TopDropdownLayout.rowIconSpacing) {
            Text(group.title)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImageName)
                .font(.system(size: TopControlLayout.iconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(
                    width: TopControlLayout.iconButtonSize,
                    height: TopControlLayout.iconButtonSize
                )
                .pushGlassBackground(cornerRadius: TopControlLayout.cornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
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
}

private enum TopDropdownLayout {
    static let horizontalPadding: CGFloat = 18
    static let labelSpacing: CGFloat = 6
    static let panelSpacing: CGFloat = 8
    static let panelPadding: CGFloat = 6
    static let panelWidth: CGFloat = 218
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
    static let horizontalMargin: CGFloat = 16
    static let dropdownWidth: CGFloat = 139.4
    static let dropdownHeight: CGFloat = 46
    static let iconButtonSize: CGFloat = 44
    static let cornerRadius: CGFloat = iconButtonSize / 2
    static let iconSize: CGFloat = 17
    static let minimumTextScale = 0.78
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
