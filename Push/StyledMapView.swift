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
    let selectedRegionalPuckID: String?
    let onPuckSelected: (MapPuckRenderModel) -> Void
    let onMapTapped: () -> Void
    let onRegionChanged: (MKCoordinateSpan) -> Void
    var layout: PushAdaptiveLayout = .reference
    var mapLayoutMargins: UIEdgeInsets = .zero

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPuckSelected: onPuckSelected,
            onMapTapped: onMapTapped,
            onRegionChanged: onRegionChanged
        )
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.layoutMargins = mapLayoutMargins
        applyStyle(to: mapView)
        context.coordinator.installTapGesture(on: mapView)
        syncAnnotations(on: mapView)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onPuckSelected = onPuckSelected
        context.coordinator.onMapTapped = onMapTapped
        context.coordinator.onRegionChanged = onRegionChanged
        mapView.layoutMargins = mapLayoutMargins
        applyStyle(to: mapView)
        applyFocusRequest(on: mapView, coordinator: context.coordinator)
        syncAnnotations(on: mapView)
    }

    private func applyStyle(to mapView: MKMapView) {
        mapView.showsCompass = false
        if #available(iOS 16.0, *) {
            guard !(mapView.preferredConfiguration is MKImageryMapConfiguration) else { return }
            mapView.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .flat)
        } else {
            guard mapView.mapType != .hybrid else { return }
            mapView.mapType = .hybrid
        }
    }

    private func syncAnnotations(on mapView: MKMapView) {
        let existingPuckAnnotations = mapView.annotations.compactMap { $0 as? MapPuckAnnotation }
        let existingByID = Dictionary(uniqueKeysWithValues: existingPuckAnnotations.map { ($0.id, $0) })
        let incomingByID = Dictionary(uniqueKeysWithValues: pucks.map { ($0.id, $0) })
        let staleAnnotations = existingPuckAnnotations.filter { annotation in
            guard let incoming = incomingByID[annotation.id] else { return true }
            return annotation.puck != incoming
                || annotation.layout != layout
                || annotation.isSelected != isSelected(incoming)
        }
        let staleIDs = Set(staleAnnotations.map(\.id))
        let newAnnotations = pucks.filter { puck in
            existingByID[puck.id] == nil || staleIDs.contains(puck.id)
        }

        if !staleAnnotations.isEmpty {
            mapView.removeAnnotations(staleAnnotations)
        }
        if !newAnnotations.isEmpty {
            mapView.addAnnotations(
                newAnnotations.map {
                    MapPuckAnnotation(
                        puck: $0,
                        layout: layout,
                        isSelected: isSelected($0)
                    )
                }
            )
        }
    }

    private func isSelected(_ puck: MapPuckRenderModel) -> Bool {
        guard case .regionalCluster = puck else { return false }
        return puck.id == selectedRegionalPuckID
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

final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
    var onPuckSelected: (MapPuckRenderModel) -> Void
    var onMapTapped: () -> Void
    var onRegionChanged: (MKCoordinateSpan) -> Void
    var lastFocusRequestID: UUID?
    private weak var mapView: MKMapView?
    private var tapGesture: UITapGestureRecognizer?

    init(
        onPuckSelected: @escaping (MapPuckRenderModel) -> Void,
        onMapTapped: @escaping () -> Void,
        onRegionChanged: @escaping (MKCoordinateSpan) -> Void
    ) {
        self.onPuckSelected = onPuckSelected
        self.onMapTapped = onMapTapped
        self.onRegionChanged = onRegionChanged
    }

    func installTapGesture(on mapView: MKMapView) {
        self.mapView = mapView
        guard tapGesture == nil else { return }
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        gesture.delegate = self
        gesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(gesture)
        tapGesture = gesture
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
        annotationView.configure(
            with: puckAnnotation.puck,
            layout: puckAnnotation.layout,
            isSelected: puckAnnotation.isSelected
        )
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

    /// MapKit default selection is neutralized — custom hit-testing owns selection.
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        mapView.deselectAnnotation(view.annotation, animated: false)
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        onRegionChanged(mapView.region.span)
    }

    @objc
    private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        guard
            gesture.state == .ended,
            let mapView
        else { return }
        let point = gesture.location(in: mapView)
        if let puck = resolvePuck(at: point, in: mapView) {
            onPuckSelected(puck)
        } else {
            onMapTapped()
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard
            gestureRecognizer === tapGesture,
            let mapView
        else { return false }
        let point = gestureRecognizer.location(in: mapView)
        return resolvePuck(at: point, in: mapView) == nil
    }

    private func resolvePuck(at point: CGPoint, in mapView: MKMapView) -> MapPuckRenderModel? {
        var candidates: [MapPuckHitTesting.Candidate] = []
        var pucksByID: [String: MapPuckRenderModel] = [:]

        for annotation in mapView.annotations {
            guard let puckAnnotation = annotation as? MapPuckAnnotation else { continue }
            let center = mapView.convert(puckAnnotation.coordinate, toPointTo: mapView)
            let radius = MapPuckHitTesting.hitRadius(
                for: puckAnnotation.puck,
                layout: puckAnnotation.layout
            )
            candidates.append(
                MapPuckHitTesting.Candidate(
                    id: puckAnnotation.id,
                    center: center,
                    radius: radius,
                    zPriority: MapPuckHitTesting.zPriority(for: puckAnnotation.puck)
                )
            )
            pucksByID[puckAnnotation.id] = puckAnnotation.puck
        }

        guard let winnerID = MapPuckHitTesting.preferredHit(among: candidates, at: point) else {
            return nil
        }
        return pucksByID[winnerID]
    }
}

private final class MapPuckAnnotation: NSObject, MKAnnotation {
    let id: String
    let puck: MapPuckRenderModel
    let layout: PushAdaptiveLayout
    let isSelected: Bool

    var coordinate: CLLocationCoordinate2D {
        puck.coordinate
    }

    init(puck: MapPuckRenderModel, layout: PushAdaptiveLayout, isSelected: Bool) {
        self.id = puck.id
        self.puck = puck
        self.layout = layout
        self.isSelected = isSelected
    }
}

private final class MapPuckAnnotationHostingView: MKAnnotationView {
    static let reuseIdentifier = "MapPuckAnnotationHostingView"

    private var hostingController: UIHostingController<MapPuckAnnotationView>?
    private var hitRadius: CGFloat = 0

    func configure(
        with puck: MapPuckRenderModel,
        layout: PushAdaptiveLayout,
        isSelected: Bool
    ) {
        let rootView = MapPuckAnnotationView(
            puck: puck,
            layout: layout,
            isSelected: isSelected
        )
        let size = MapPuckAnnotationView.size(for: puck, layout: layout)
        bounds = CGRect(origin: .zero, size: size)
        centerOffset = .zero
        canShowCallout = false
        hitRadius = MapPuckHitTesting.hitRadius(for: puck, layout: layout)
        zPriority = MKAnnotationViewZPriority(
            rawValue: MapPuckHitTesting.zPriority(for: puck)
        )

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

    /// Only the visual puck circle (plus light padding) is tappable, not the full frame.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let dx = point.x - bounds.midX
        let dy = point.y - bounds.midY
        return (dx * dx + dy * dy) <= hitRadius * hitRadius
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostingController?.view.removeFromSuperview()
        hostingController = nil
        hitRadius = 0
    }
}

private struct MapPuckAnnotationView: View {
    let puck: MapPuckRenderModel
    let layout: PushAdaptiveLayout
    let isSelected: Bool

    var body: some View {
        puckView
            .frame(
                width: Self.size(for: puck, layout: layout).width,
                height: Self.size(for: puck, layout: layout).height
            )
            .shadow(
                color: .black.opacity(MapPuckAnnotationLayout.shadowOpacity),
                radius: MapPuckAnnotationLayout.shadowRadius,
                y: MapPuckAnnotationLayout.shadowYOffset
            )
    }

    static func size(for puck: MapPuckRenderModel, layout: PushAdaptiveLayout) -> CGSize {
        switch puck {
        case .selfPuck:
            return SelfPuckAnnotationLayout.frameSize(layout)
        case .friend:
            return MapPuckAnnotationLayout.individualFrameSize(layout)
        case .smallGroup:
            return MapPuckAnnotationLayout.groupFrameSize(layout)
        case .regionalCluster:
            return MapPuckAnnotationLayout.regionalFrameSize(layout)
        }
    }

    @ViewBuilder
    private var puckView: some View {
        switch puck {
        case .selfPuck(let data):
            SelfPuckView(data: data)
        case .friend(let puck):
            if let friend = puck.people.first {
                FriendPuck(friend: friend, size: MapPuckAnnotationLayout.individualPuckSize(layout))
            }
        case .smallGroup(let puck):
            if puck.kind == .friendGroup {
                FriendGroupPuck(friends: puck.people, size: MapPuckAnnotationLayout.friendGroupPuckSize(layout))
            } else {
                FriendClusterPuck(friends: puck.people, size: MapPuckAnnotationLayout.clusterPuckSize(layout))
            }
        case .regionalCluster(let puck):
            RegionalActivityPuck(model: puck, isSelected: isSelected)
        }
    }
}

enum MapPuckAnnotationLayout {
    static func individualPuckSize(_ layout: PushAdaptiveLayout) -> CGFloat { 82 * layout.puckScale }
    static func clusterPuckSize(_ layout: PushAdaptiveLayout) -> CGFloat { 116 * layout.puckScale }
    static func friendGroupPuckSize(_ layout: PushAdaptiveLayout) -> CGFloat { 92 * layout.puckScale }
    static let regionalPuckSize: CGFloat = 106
    static func individualFrameSize(_ layout: PushAdaptiveLayout) -> CGSize {
        CGSize(width: 126 * layout.puckScale, height: 126 * layout.puckScale)
    }
    static func groupFrameSize(_ layout: PushAdaptiveLayout) -> CGSize {
        CGSize(width: 164 * layout.puckScale, height: 154 * layout.puckScale)
    }
    static func regionalFrameSize(_ layout: PushAdaptiveLayout) -> CGSize {
        let metrics = RegionalActivityPuckMetrics(memberCount: 16, scale: layout.puckScale)
        return CGSize(width: metrics.frameWidth, height: metrics.frameHeight)
    }
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
        let size = SelfPuckAnnotationLayout.frameSize(.reference)
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

enum SelfPuckAnnotationLayout {
    static func frameSize(_ layout: PushAdaptiveLayout) -> CGSize {
        CGSize(width: 132 * layout.puckScale, height: 124 * layout.puckScale)
    }

    /// Drawn avatar core size (matches `SelfPuckLayout.puckSize`).
    static func visualDiameter(_ layout: PushAdaptiveLayout) -> CGFloat {
        58 * layout.puckScale
    }
}
