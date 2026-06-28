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

    var body: some View {
        ZStack(alignment: .bottom) {
            StyledMapView(region: MapDefaults.region)
                .ignoresSafeArea()

            BottomNavigationBar(selectedItem: $selectedNavigationItem)
                .padding(.horizontal, BottomNavigationLayout.horizontalMargin)
                .padding(.bottom, BottomNavigationLayout.bottomMargin)
        }
        .overlay(alignment: .top) {
            HStack(alignment: .center, spacing: 0) {
                TopIconButton(systemImageName: "bell.fill", accessibilityLabel: "Notifications")

                Spacer(minLength: 0)

                FriendGroupDropdown(selectedGroup: $selectedFriendGroup)
                    .frame(width: TopControlLayout.dropdownWidth)

                Spacer(minLength: 0)

                TopIconButton(systemImageName: "person.crop.circle.fill", accessibilityLabel: "Profile")
            }
            .padding(.horizontal, TopControlLayout.horizontalMargin)
            .padding(.top, TopControlLayout.topMargin)
        }
    }
}

enum FriendGroupFilter: String, CaseIterable, Identifiable {
    case allFriends
    case collegeFriends
    case gymCrew
    case roommates
    case nycFriends

    var id: Self { self }

    var title: String {
        switch self {
        case .allFriends:
            return "All Friends"
        case .collegeFriends:
            return "College Friends"
        case .gymCrew:
            return "Gym Crew"
        case .roommates:
            return "Roommates"
        case .nycFriends:
            return "NYC Friends"
        }
    }
}

enum BottomNavigationItem: String, CaseIterable, Identifiable {
    case map
    case group
    case create
    case feed
    case plans

    var id: Self { self }

    var title: String {
        switch self {
        case .map:
            return "Map"
        case .group:
            return "Group"
        case .create:
            return "+"
        case .feed:
            return "Feed"
        case .plans:
            return "Plans"
        }
    }

    var systemImageName: String {
        switch self {
        case .map:
            return "map.fill"
        case .group:
            return "person.2.fill"
        case .create:
            return "plus"
        case .feed:
            return "list.bullet"
        case .plans:
            return "calendar"
        }
    }

    var isPrimaryAction: Bool {
        self == .create
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

    var body: some View {
        Button {
        } label: {
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

private struct BottomNavigationBar: View {
    @Binding var selectedItem: BottomNavigationItem

    var body: some View {
        PushGlass {
            HStack(spacing: BottomNavigationLayout.itemSpacing) {
                ForEach(BottomNavigationItem.allCases) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        if item.isPrimaryAction {
                            PrimaryNavigationButtonLabel(isSelected: selectedItem == item)
                        } else {
                            BottomNavigationButtonLabel(
                                item: item,
                                isSelected: selectedItem == item
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityValue(selectedItem == item ? "Selected" : "Not selected")
                }
            }
        }
    }
}

private struct BottomNavigationButtonLabel: View {
    let item: BottomNavigationItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: BottomNavigationLayout.labelSpacing) {
            Image(systemName: item.systemImageName)
                .font(.system(size: BottomNavigationLayout.iconSize, weight: .semibold))

            Text(item.title)
                .font(.caption2.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(isSelected ? PushControlColors.activeForeground : PushControlColors.inactiveForeground)
        .padding(.vertical, BottomNavigationLayout.itemVerticalPadding)
        .padding(.horizontal, BottomNavigationLayout.itemHorizontalPadding)
        .background(selectionBackground)
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            Capsule()
                .fill(PushControlColors.activeFill)
        }
    }
}

private struct PrimaryNavigationButtonLabel: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: BottomNavigationItem.create.systemImageName)
            .font(.system(size: BottomNavigationLayout.primaryIconSize, weight: .bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(
                width: BottomNavigationLayout.primaryButtonSize,
                height: BottomNavigationLayout.primaryButtonSize
            )
            .background(primaryBackground)
            .overlay {
                Circle()
                    .stroke(
                        PushControlColors.activeForeground.opacity(PushControlStyle.primaryStrokeOpacity),
                        lineWidth: BottomNavigationLayout.primaryStrokeWidth
                    )
            }
            .shadow(
                color: PushControlColors.activeForeground.opacity(PushControlStyle.primaryGlowOpacity),
                radius: BottomNavigationLayout.primaryGlowRadius,
                y: BottomNavigationLayout.primaryGlowYOffset
            )
            .scaleEffect(isSelected ? BottomNavigationLayout.selectedPrimaryScale : 1)
    }

    private var primaryBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .background {
                Circle()
                    .fill(.white.opacity(PushGlassStyle.tintOpacity))
            }
    }
}

private struct PushGlass<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(BottomNavigationLayout.containerPadding)
            .pushGlassBackground(cornerRadius: BottomNavigationLayout.containerCornerRadius)
    }
}

private extension View {
    @ViewBuilder
    func pushGlassBackground(cornerRadius: CGFloat) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            pushMaterialBackground(cornerRadius: cornerRadius)
        }
        #else
        pushMaterialBackground(cornerRadius: cornerRadius)
        #endif
    }

    func pushMaterialBackground(cornerRadius: CGFloat) -> some View {
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.regularMaterial.opacity(PushGlassStyle.materialPresenceOpacity))
        )
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(PushGlassStyle.tintOpacity))
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    .white.opacity(PushGlassStyle.strokeOpacity),
                    lineWidth: PushGlassStyle.strokeWidth
                )
        }
        .shadow(
            color: .black.opacity(PushGlassStyle.shadowOpacity),
            radius: PushGlassStyle.shadowRadius,
            y: PushGlassStyle.shadowYOffset
        )
    }
}

private struct StyledMapView: UIViewRepresentable {
    let region: MKCoordinateRegion

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.setRegion(region, animated: false)
        applyStyle(to: mapView)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        applyStyle(to: mapView)
    }

    private func applyStyle(to mapView: MKMapView) {
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsTraffic = false

        if #available(iOS 16.0, *) {
            let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
            configuration.emphasisStyle = .muted
            configuration.pointOfInterestFilter = .excludingAll
            configuration.showsTraffic = false
            mapView.preferredConfiguration = configuration
        } else {
            mapView.mapType = .mutedStandard
        }
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

private enum BottomNavigationLayout {
    static let horizontalMargin: CGFloat = 20
    static let bottomMargin: CGFloat = 18
    static let containerPadding: CGFloat = 8
    static let containerCornerRadius: CGFloat = 32
    static let itemSpacing: CGFloat = 6
    static let labelSpacing: CGFloat = 4
    static let iconSize: CGFloat = 17
    static let itemVerticalPadding: CGFloat = 10
    static let itemHorizontalPadding: CGFloat = 2
    static let primaryButtonSize: CGFloat = 50
    static let primaryIconSize: CGFloat = 21
    static let selectedPrimaryScale = 1.04
    static let primaryStrokeWidth: CGFloat = 1
    static let primaryGlowRadius: CGFloat = 10
    static let primaryGlowYOffset: CGFloat = 3
}

enum PushGlassStyle {
    static let materialPresenceOpacity = 0.72
    static let tintOpacity = 0.24
    static let strokeOpacity = 0.62
    static let strokeWidth: CGFloat = 0.8
    static let shadowOpacity = 0.24
    static let shadowRadius: CGFloat = 26
    static let shadowYOffset: CGFloat = 12
}

enum PushControlStyle {
    static let activeFillOpacity = 1.0
    static let inactiveForegroundOpacity = 0.7
    static let primaryStrokeOpacity = 0.72
    static let primaryGlowOpacity = 0.34
}

enum PushControlColors {
    static let activeForeground = PushColorPalette.Accent.walnut
    static let inactiveForeground = PushColorPalette.Accent.walnut.opacity(PushControlStyle.inactiveForegroundOpacity)
    static let activeFill = PushColorPalette.Accent.sunbeam.opacity(PushControlStyle.activeFillOpacity)
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
