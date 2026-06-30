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
    let pucks: [MapPuckData]
    let onPuckSelected: (MapPuckData) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPuckSelected: onPuckSelected)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        applyStyle(to: mapView)
        syncAnnotations(on: mapView)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        applyStyle(to: mapView)
        syncAnnotations(on: mapView)
    }

    private func applyStyle(to mapView: MKMapView) {
        if #available(iOS 16.0, *) {
            mapView.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .realistic)
        } else {
            mapView.mapType = .hybrid
        }
    }

    private func syncAnnotations(on mapView: MKMapView) {
        let existingPuckAnnotations = mapView.annotations.compactMap { $0 as? MapPuckAnnotation }
        mapView.removeAnnotations(existingPuckAnnotations)
        mapView.addAnnotations(pucks.map(MapPuckAnnotation.init))
    }
}

final class Coordinator: NSObject, MKMapViewDelegate {
    private let onPuckSelected: (MapPuckData) -> Void

    init(onPuckSelected: @escaping (MapPuckData) -> Void) {
        self.onPuckSelected = onPuckSelected
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
        return annotationView
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? MapPuckAnnotation else { return }
        mapView.deselectAnnotation(annotation, animated: false)
        onPuckSelected(annotation.puck)
    }
}

private final class MapPuckAnnotation: NSObject, MKAnnotation {
    let puck: MapPuckData

    var coordinate: CLLocationCoordinate2D {
        puck.coordinate
    }

    init(puck: MapPuckData) {
        self.puck = puck
    }
}

private final class MapPuckAnnotationHostingView: MKAnnotationView {
    static let reuseIdentifier = "MapPuckAnnotationHostingView"

    private var hostingController: UIHostingController<MapPuckAnnotationView>?

    func configure(with puck: MapPuckData) {
        let rootView = MapPuckAnnotationView(puck: puck)
        let size = MapPuckAnnotationView.size(for: puck.kind)
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
    let puck: MapPuckData

    var body: some View {
        puckView
            .frame(
                width: Self.size(for: puck.kind).width,
                height: Self.size(for: puck.kind).height
            )
            .shadow(
                color: .black.opacity(MapPuckAnnotationLayout.shadowOpacity),
                radius: MapPuckAnnotationLayout.shadowRadius,
                y: MapPuckAnnotationLayout.shadowYOffset
            )
    }

    static func size(for kind: MapPuckKind) -> CGSize {
        switch kind {
        case .individual:
            return MapPuckAnnotationLayout.individualFrameSize
        case .hangout, .cluster, .friendGroup:
            return MapPuckAnnotationLayout.groupFrameSize
        }
    }

    @ViewBuilder
    private var puckView: some View {
        switch puck.kind {
        case .individual:
            if let friend = puck.people.first {
                FriendPuck(friend: friend, size: MapPuckAnnotationLayout.individualPuckSize)
            }
        case .hangout, .cluster:
            FriendClusterPuck(friends: puck.people, size: MapPuckAnnotationLayout.clusterPuckSize)
        case .friendGroup:
            FriendGroupPuck(friends: puck.people, size: MapPuckAnnotationLayout.friendGroupPuckSize)
        }
    }
}

private enum MapPuckAnnotationLayout {
    static let individualPuckSize: CGFloat = 82
    static let clusterPuckSize: CGFloat = 116
    static let friendGroupPuckSize: CGFloat = 92
    static let individualFrameSize = CGSize(width: 126, height: 126)
    static let groupFrameSize = CGSize(width: 164, height: 154)
    static let shadowOpacity = 0.28
    static let shadowRadius: CGFloat = 16
    static let shadowYOffset: CGFloat = 8
}
