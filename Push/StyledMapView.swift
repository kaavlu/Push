//
//  StyledMapView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/28/26.
//

import MapKit
import SwiftUI

struct StyledMapView: UIViewRepresentable {
    let region: MKCoordinateRegion
    let pucks: [MapPuckRenderModel]
    let focusRequest: MapFocusRequest?
    let onPuckSelected: (MapPuckRenderModel) -> Void
    let onRegionChanged: (MKCoordinateSpan) -> Void
    var mapLayoutMargins: UIEdgeInsets = .zero

    func makeCoordinator() -> Coordinator {
        Coordinator(onPuckSelected: onPuckSelected, onRegionChanged: onRegionChanged)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.layoutMargins = mapLayoutMargins
        applyStyle(to: mapView)
        syncAnnotations(on: mapView)
        placeCompass(on: mapView)
        return mapView
    }

    private func placeCompass(on mapView: MKMapView) {
        mapView.showsCompass = false
        let compass = MKCompassButton(mapView: mapView)
        compass.compassVisibility = .visible
        compass.translatesAutoresizingMaskIntoConstraints = false
        mapView.addSubview(compass)
        NSLayoutConstraint.activate([
            compass.trailingAnchor.constraint(
                equalTo: mapView.safeAreaLayoutGuide.trailingAnchor,
                constant: -CompassLayout.trailingMargin
            ),
            compass.topAnchor.constraint(
                equalTo: mapView.safeAreaLayoutGuide.topAnchor,
                constant: CompassLayout.topMargin
            )
        ])
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onRegionChanged = onRegionChanged
        mapView.layoutMargins = mapLayoutMargins
        applyStyle(to: mapView)
        applyFocusRequest(on: mapView, coordinator: context.coordinator)
        syncAnnotations(on: mapView)
    }

    private func applyStyle(to mapView: MKMapView) {
        if #available(iOS 16.0, *) {
            guard !(mapView.preferredConfiguration is MKImageryMapConfiguration) else { return }
            mapView.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
        } else {
            guard mapView.mapType != .hybrid else { return }
            mapView.mapType = .hybrid
        }
    }

    private func syncAnnotations(on mapView: MKMapView) {
        let existingPuckAnnotations = mapView.annotations.compactMap { $0 as? MapPuckAnnotation }
        mapView.removeAnnotations(existingPuckAnnotations)
        mapView.addAnnotations(pucks.map(MapPuckAnnotation.init))
    }

    private func applyFocusRequest(on mapView: MKMapView, coordinator: Coordinator) {
        guard
            let focusRequest,
            coordinator.lastFocusRequestID != focusRequest.id
        else { return }
        coordinator.lastFocusRequestID = focusRequest.id
        mapView.setRegion(focusRequest.region, animated: true)
    }
}

final class Coordinator: NSObject, MKMapViewDelegate {
    private let onPuckSelected: (MapPuckRenderModel) -> Void
    var onRegionChanged: (MKCoordinateSpan) -> Void
    var lastFocusRequestID: UUID?

    init(
        onPuckSelected: @escaping (MapPuckRenderModel) -> Void,
        onRegionChanged: @escaping (MKCoordinateSpan) -> Void
    ) {
        self.onPuckSelected = onPuckSelected
        self.onRegionChanged = onRegionChanged
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let puckAnnotation = annotation as? MapPuckAnnotation else {
            return nil
        }

        let annotationView = mapView.dequeueReusableAnnotationView(
            withIdentifier: MapPuckAnnotationHostingView.reuseIdentifier
        ) as? MapPuckAnnotationHostingView ?? MapPuckAnnotationHostingView(
            annotation: annotation,
            reuseIdentifier: MapPuckAnnotationHostingView.reuseIdentifier
        )
        annotationView.configure(with: puckAnnotation.puck)
        annotationView.alpha = 0
        annotationView.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
        UIView.animate(
            withDuration: MapPuckAnnotationLayout.appearDuration,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction]
        ) {
            annotationView.alpha = 1
            annotationView.transform = .identity
        }
        return annotationView
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? MapPuckAnnotation else { return }
        mapView.deselectAnnotation(annotation, animated: false)
        onPuckSelected(annotation.puck)
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        onRegionChanged(mapView.region.span)
    }
}

private final class MapPuckAnnotation: NSObject, MKAnnotation {
    let puck: MapPuckRenderModel

    var coordinate: CLLocationCoordinate2D {
        puck.coordinate
    }

    init(puck: MapPuckRenderModel) {
        self.puck = puck
    }
}

private final class MapPuckAnnotationHostingView: MKAnnotationView {
    static let reuseIdentifier = "MapPuckAnnotationHostingView"

    private var hostingController: UIHostingController<MapPuckAnnotationView>?

    func configure(with puck: MapPuckRenderModel) {
        let rootView = MapPuckAnnotationView(puck: puck)
        let size = MapPuckAnnotationView.size(for: puck)
        bounds = CGRect(origin: .zero, size: size)
        centerOffset = .zero
        canShowCallout = false

        if let hostingController {
            hostingController.rootView = rootView
            hostingController.view.frame = bounds
        } else {
            let hostingController = UIHostingController(rootView: rootView)
            hostingController.view.backgroundColor = .clear
            hostingController.view.frame = bounds
            addSubview(hostingController.view)
            self.hostingController = hostingController
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostingController?.view.removeFromSuperview()
        hostingController = nil
    }
}

private struct MapPuckAnnotationView: View {
    let puck: MapPuckRenderModel

    var body: some View {
        puckView
            .frame(
                width: Self.size(for: puck).width,
                height: Self.size(for: puck).height
            )
            .shadow(
                color: .black.opacity(MapPuckAnnotationLayout.shadowOpacity),
                radius: MapPuckAnnotationLayout.shadowRadius,
                y: MapPuckAnnotationLayout.shadowYOffset
            )
    }

    static func size(for puck: MapPuckRenderModel) -> CGSize {
        switch puck {
        case .selfPuck:
            return SelfPuckAnnotationLayout.frameSize
        case .friend:
            return MapPuckAnnotationLayout.individualFrameSize
        case .smallGroup:
            return MapPuckAnnotationLayout.groupFrameSize
        case .regionalCluster:
            return MapPuckAnnotationLayout.regionalFrameSize
        }
    }

    @ViewBuilder
    private var puckView: some View {
        switch puck {
        case .selfPuck(let data):
            SelfPuckView(data: data)
        case .friend(let puck):
            if let friend = puck.people.first {
                FriendPuck(friend: friend, size: MapPuckAnnotationLayout.individualPuckSize)
            }
        case .smallGroup(let puck):
            if puck.kind == .friendGroup {
                FriendGroupPuck(friends: puck.people, size: MapPuckAnnotationLayout.friendGroupPuckSize)
            } else {
                FriendClusterPuck(friends: puck.people, size: MapPuckAnnotationLayout.clusterPuckSize)
            }
        case .regionalCluster(let puck):
            RegionalActivityPuck(model: puck)
        }
    }
}

private enum MapPuckAnnotationLayout {
    static let individualPuckSize: CGFloat = 82
    static let clusterPuckSize: CGFloat = 116
    static let friendGroupPuckSize: CGFloat = 92
    static let regionalPuckSize: CGFloat = 106
    static let individualFrameSize = CGSize(width: 126, height: 126)
    static let groupFrameSize = CGSize(width: 164, height: 154)
    static let regionalFrameSize = CGSize(width: 154, height: 154)
    static let shadowOpacity = 0.28
    static let shadowRadius: CGFloat = 16
    static let shadowYOffset: CGFloat = 8
    static let appearDuration = 0.22
}

// MARK: - Self Puck

final class SelfPuckAnnotation: NSObject, MKAnnotation {
    let data: SelfPuckData

    var coordinate: CLLocationCoordinate2D {
        data.coordinate
    }

    init(data: SelfPuckData) {
        self.data = data
    }
}

final class SelfPuckAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "SelfPuckAnnotationView"
    private var hostingController: UIHostingController<SelfPuckView>?

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        let size = SelfPuckAnnotationLayout.frameSize
        bounds = CGRect(origin: .zero, size: size)
        centerOffset = .zero
        canShowCallout = false
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { nil }

    func configure(with data: SelfPuckData) {
        let rootView = SelfPuckView(data: data)
        if let hostingController {
            hostingController.rootView = rootView
            hostingController.view.frame = bounds
        } else {
            let hostingController = UIHostingController(rootView: rootView)
            hostingController.view.backgroundColor = .clear
            hostingController.view.frame = bounds
            addSubview(hostingController.view)
            self.hostingController = hostingController
        }
    }
}

private enum SelfPuckAnnotationLayout {
    static let frameSize = CGSize(width: 132, height: 124)
}

private enum CompassLayout {
    static let trailingMargin: CGFloat = 16
    static let topMargin: CGFloat = 10
}
