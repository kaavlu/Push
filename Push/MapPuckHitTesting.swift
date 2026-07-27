//
//  MapPuckHitTesting.swift
//  Push
//
//  Size-aware circular hit targets and larger/group-first priority for map pucks.
//

import CoreGraphics
import Foundation

enum MapPuckHitTesting {
    /// Extra touch padding beyond the visual puck radius (light fat-finger assist).
    static let hitPadding: CGFloat = 10

    /// Higher draws above lower and wins overlapping taps.
    enum ZPriority {
        static let regional: Float = 800
        static let hangoutCluster: Float = 700
        static let friendGroup: Float = 650
        static let friend: Float = 600
        static let selfPuck: Float = 500
    }

    struct Candidate: Equatable {
        let id: String
        let center: CGPoint
        let radius: CGFloat
        let zPriority: Float
    }

    static func hitRadius(for puck: MapPuckRenderModel, layout: PushAdaptiveLayout) -> CGFloat {
        visualDiameter(for: puck, layout: layout) / 2 + hitPadding
    }

    static func zPriority(for puck: MapPuckRenderModel) -> Float {
        switch puck {
        case .regionalCluster:
            return ZPriority.regional
        case .smallGroup(let data):
            switch data.kind {
            case .hangout, .cluster:
                return ZPriority.hangoutCluster
            case .friendGroup:
                return ZPriority.friendGroup
            case .individual:
                return ZPriority.friend
            }
        case .friend:
            return ZPriority.friend
        case .selfPuck:
            return ZPriority.selfPuck
        }
    }

    /// Among candidates whose circle contains `point`, prefer highest z-priority,
    /// then closest center.
    static func preferredHit(among candidates: [Candidate], at point: CGPoint) -> String? {
        var bestID: String?
        var bestZ: Float = -.greatestFiniteMagnitude
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for candidate in candidates {
            let dx = point.x - candidate.center.x
            let dy = point.y - candidate.center.y
            let distance = hypot(dx, dy)
            guard distance <= candidate.radius else { continue }

            let isBetterPriority = candidate.zPriority > bestZ
            let isCloserSamePriority =
                candidate.zPriority == bestZ && distance < bestDistance
            guard isBetterPriority || isCloserSamePriority else { continue }

            bestID = candidate.id
            bestZ = candidate.zPriority
            bestDistance = distance
        }

        return bestID
    }

    // MARK: - Visual diameter (matches annotation layout sizes)

    static func visualDiameter(for puck: MapPuckRenderModel, layout: PushAdaptiveLayout) -> CGFloat {
        switch puck {
        case .friend:
            return MapPuckAnnotationLayout.individualPuckSize(layout)
        case .smallGroup(let data):
            if data.kind == .friendGroup {
                return MapPuckAnnotationLayout.friendGroupPuckSize(layout)
            }
            return MapPuckAnnotationLayout.clusterPuckSize(layout)
        case .regionalCluster(let model):
            return regionalVisualDiameter(memberCount: model.memberCount, layout: layout)
        case .selfPuck:
            return SelfPuckAnnotationLayout.visualDiameter(layout)
        }
    }

    private static func regionalVisualDiameter(
        memberCount: Int,
        layout: PushAdaptiveLayout
    ) -> CGFloat {
        RegionalActivityPuckLayout.coreSize(
            memberCount: memberCount,
            scale: layout.puckScale
        )
    }
}
