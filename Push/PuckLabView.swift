//
//  PuckLabView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/28/26.
//

#if DEBUG
import MapKit
import SwiftUI

struct PuckLabView: View {
    @State private var selectedItemID: String?

    var body: some View {
        ZStack {
            PuckLabMapBackdrop()
                .ignoresSafeArea()
                .onTapGesture { selectedItemID = nil }

            ScrollView {
                VStack(alignment: .leading, spacing: PuckLabLayout.sectionSpacing) {
                    header
                    puckColumn
                }
                .padding(.horizontal, PuckLabLayout.horizontalPadding)
                .padding(.vertical, PuckLabLayout.verticalPadding)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PuckLabLayout.headerSpacing) {
            Text("Puck Lab")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(PuckLabColors.primaryText)
                .shadow(color: PuckLabColors.headerShadow, radius: PuckLabLayout.headerShadowRadius, y: PuckLabLayout.headerShadowYOffset)

            Text("Single-friend puck states first, with clusters still available for comparison.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PuckLabColors.secondaryText)
                .shadow(color: PuckLabColors.headerShadow, radius: PuckLabLayout.headerShadowRadius, y: PuckLabLayout.headerShadowYOffset)
        }
        .padding(.top, PuckLabLayout.headerTopPadding)
    }

    private var puckColumn: some View {
        VStack(alignment: .leading, spacing: PuckLabLayout.puckRowSpacing) {
            PuckLabPuckRow(
                item: .selfPuck,
                isSelected: selectedItemID == PuckLabItem.selfPuck.id,
                onTap: { toggleSelection(PuckLabItem.selfPuck.id) }
            )

            ForEach(PuckLabFixtures.scenarios) { scenario in
                let item = PuckLabItem.scenario(scenario)
                PuckLabPuckRow(
                    item: item,
                    isSelected: selectedItemID == item.id,
                    onTap: { toggleSelection(item.id) }
                )
            }
        }
    }

    private func toggleSelection(_ id: String) {
        selectedItemID = selectedItemID == id ? nil : id
    }
}

private struct PuckLabPuckRow: View {
    let item: PuckLabItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: PuckLabLayout.popupSpacing) {
            Button(action: onTap) {
                puck
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.title)

            if isSelected {
                PuckLabDescriptionPopup(item: item)
                    .transition(
                        .opacity
                            .combined(with: .scale(scale: PuckLabLayout.popupTransitionScale, anchor: .leading))
                    )
            }
        }
        .frame(height: item.rowHeight, alignment: .leading)
        .animation(.spring(response: PuckLabLayout.popupAnimationResponse, dampingFraction: PuckLabLayout.popupAnimationDamping), value: isSelected)
    }

    @ViewBuilder
    private var puck: some View {
        switch item {
        case .selfPuck:
            SelfPuckView(data: PuckLabSelfPuck.fixture)
                .frame(width: PuckLabMapSizing.selfFrameSize.width, height: PuckLabMapSizing.selfFrameSize.height)
        case .scenario(let scenario):
            if scenario.puckStyle == .friendGroup {
                FriendGroupPuck(friends: scenario.friends, size: PuckLabMapSizing.friendGroupPuckSize)
                    .frame(width: PuckLabMapSizing.groupFrameSize.width, height: PuckLabMapSizing.groupFrameSize.height)
            } else if let friend = scenario.friends.first, scenario.friends.count == PuckLabLayout.singleFriendCount {
                FriendPuck(friend: friend, size: PuckLabMapSizing.individualPuckSize)
                    .frame(width: PuckLabMapSizing.individualFrameSize.width, height: PuckLabMapSizing.individualFrameSize.height)
            } else {
                FriendClusterPuck(friends: scenario.friends, size: PuckLabMapSizing.clusterPuckSize)
                    .frame(width: PuckLabMapSizing.groupFrameSize.width, height: PuckLabMapSizing.groupFrameSize.height)
            }
        }
    }
}

private struct PuckLabDescriptionPopup: View {
    let item: PuckLabItem

    var body: some View {
        VStack(alignment: .leading, spacing: PuckLabLayout.popupTextSpacing) {
            Text(item.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PuckLabColors.popupPrimaryText)
                .lineLimit(PuckLabLayout.titleLineLimit)

            Text(item.subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(PuckLabColors.popupSecondaryText)
                .lineLimit(PuckLabLayout.popupSubtitleLineLimit)

            Text(item.metadata)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PuckLabColors.popupTertiaryText)
                .lineLimit(PuckLabLayout.metadataLineLimit)
        }
        .frame(width: PuckLabLayout.popupWidth, alignment: .leading)
        .padding(.horizontal, PuckLabLayout.popupHorizontalPadding)
        .padding(.vertical, PuckLabLayout.popupVerticalPadding)
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: PuckLabLayout.popupCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .background {
                    RoundedRectangle(cornerRadius: PuckLabLayout.popupCornerRadius, style: .continuous)
                        .fill(PuckLabColors.popupTint)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: PuckLabLayout.popupCornerRadius, style: .continuous)
                .stroke(PuckLabColors.popupStroke, lineWidth: PuckLabLayout.popupStrokeWidth)
        }
        .modifier(PuckLabCardScrim())
    }
}

private enum PuckLabItem: Identifiable {
    case selfPuck
    case scenario(PuckLabScenario)

    var id: String {
        switch self {
        case .selfPuck:
            return "self-puck"
        case .scenario(let scenario):
            return scenario.id
        }
    }

    var title: String {
        switch self {
        case .selfPuck:
            return "Self Puck"
        case .scenario(let scenario):
            return scenario.title
        }
    }

    var subtitle: String {
        switch self {
        case .selfPuck:
            return "Current-user location anchor"
        case .scenario(let scenario):
            return scenario.subtitle
        }
    }

    var metadata: String {
        switch self {
        case .selfPuck:
            return "You"
        case .scenario(let scenario):
            return scenario.friends.map(\.availability.title).joined(separator: " - ")
        }
    }

    var rowHeight: CGFloat {
        switch self {
        case .selfPuck:
            return PuckLabMapSizing.selfFrameSize.height
        case .scenario(let scenario):
            return scenario.friends.count == PuckLabLayout.singleFriendCount
                ? PuckLabMapSizing.individualFrameSize.height
                : PuckLabMapSizing.groupFrameSize.height
        }
    }
}

private struct PuckLabMapBackdrop: UIViewRepresentable {
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.setRegion(PuckLabMapRegion.region, animated: false)
        mapView.isUserInteractionEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false
        if #available(iOS 16.0, *) {
            mapView.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
        } else {
            mapView.mapType = .hybrid
        }
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(PuckLabMapRegion.region, animated: false)
    }
}

private enum PuckLabSelfPuck {
    static let fixture = SelfPuckData(
        id: "puck-lab-self",
        avatarPlaceholder: "MK",
        profileImageAssetName: "assets/profile/manav.jpeg",
        coordinate: PuckLabMapRegion.region.center
    )
}

private enum PuckLabMapRegion {
    static let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
        span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
    )

    private static let latitude = 37.7749
    private static let longitude = -122.4194
    private static let latitudeDelta = 0.08
    private static let longitudeDelta = 0.08
}

private enum PuckLabMapSizing {
    static let individualPuckSize: CGFloat = 82
    static let clusterPuckSize: CGFloat = 116
    static let friendGroupPuckSize: CGFloat = 92
    static let individualFrameSize = CGSize(width: 126, height: 126)
    static let groupFrameSize = CGSize(width: 164, height: 154)
    static let selfFrameSize = CGSize(width: 132, height: 124)
}

private struct PuckLabCardScrim: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(
                color: PuckLabColors.warmShadow,
                radius: PuckLabLayout.cardShadowRadius,
                y: PuckLabLayout.cardShadowYOffset
            )
    }
}

private enum PuckLabColors {
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.72)
    static let popupPrimaryText = PushColorPalette.Accent.walnut
    static let popupSecondaryText = PushColorPalette.Accent.walnut.opacity(0.72)
    static let popupTertiaryText = PushColorPalette.Accent.walnut.opacity(0.56)
    static let popupTint = PushColorPalette.Accent.sunbeam.opacity(0.16)
    static let popupStroke = Color.white.opacity(0.56)
    static let warmShadow = PushColorPalette.Accent.walnut.opacity(0.22)
    static let headerShadow = PushColorPalette.Accent.walnut.opacity(0.38)
}

private enum PuckLabLayout {
    static let sectionSpacing: CGFloat = 24
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 24
    static let headerSpacing: CGFloat = 6
    static let headerTopPadding: CGFloat = 16
    static let headerShadowRadius: CGFloat = 12
    static let headerShadowYOffset: CGFloat = 4
    static let cardShadowRadius: CGFloat = 18
    static let cardShadowYOffset: CGFloat = 8
    static let puckRowSpacing: CGFloat = 22
    static let popupSpacing: CGFloat = 10
    static let popupWidth: CGFloat = 170
    static let popupHorizontalPadding: CGFloat = 14
    static let popupVerticalPadding: CGFloat = 12
    static let popupCornerRadius: CGFloat = 18
    static let popupStrokeWidth: CGFloat = 0.8
    static let popupTextSpacing: CGFloat = 4
    static let popupTransitionScale = 0.96
    static let popupAnimationResponse = 0.28
    static let popupAnimationDamping = 0.84
    static let titleLineLimit = 1
    static let popupSubtitleLineLimit = 2
    static let metadataLineLimit = 1
    static let singleFriendCount = 1
}

struct PuckLabView_Previews: PreviewProvider {
    static var previews: some View {
        PuckLabView()
    }
}
#endif
