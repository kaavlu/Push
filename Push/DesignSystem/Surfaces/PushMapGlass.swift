//
//  PushMapGlass.swift
//  Push
//
//  DS-011 — map-scoped glass family (top controls + popup sheets).
//

import SwiftUI

/// Map top-control variants — richer treatment over satellite imagery.
enum PushMapControlTreatment {
    case standard
    case filterPill
    case profileButton
}

enum PushMapGlassTokens {
    static let fill = PushControlGlassTokens.warmTint.opacity(0.38)
    static let stroke = Color.white.opacity(PushControlGlassTokens.strokeOpacity)
    static let shadow = PushControlGlassTokens.shadowColor.opacity(PushControlGlassTokens.shadowOpacity)
    static let pillCreamGlowOpacity = 0.28
    static let pillGlowOpacity = 0.18
    static let pillHighlightOpacity = 0.84
    static let profileRingOpacity = 0.52
    static let profileCenterOpacity = 0.16
    static let profileCoreOpacity = 0.26
    static let profileCreamGlowOpacity = 0.20
    static let highlightOpacity = 0.72
    static let highlightSideOpacity = 0.14

    static let strokeWidth: CGFloat = 1
    static let profileRingWidth: CGFloat = 1.15
    static let highlightWidth: CGFloat = 0.8
    static let highlightInset: CGFloat = 1.2
    static let pillGlowRadius: CGFloat = 58
    static let profileGlowRadius: CGFloat = 24
    static let shadowRadius: CGFloat = 22
    static let shadowYOffset: CGFloat = 10

    // Sheet popup (friend detail / day detail)
    static let sheetCreamFill = PushControlGlassTokens.warmTint.opacity(0.38)
    static let sheetCreamGlowOpacity = 0.28
    static let sheetSunbeamGlowOpacity = 0.18
    static let sheetStroke = Color.white.opacity(PushControlGlassTokens.strokeOpacity)
    static let sheetHighlightTopOpacity = 0.72
    static let sheetHighlightSideOpacity = 0.14
    static let sheetStrokeWidth: CGFloat = 1
    static let sheetHighlightWidth: CGFloat = 0.8
    static let sheetHighlightInset: CGFloat = 1.2
    static let sheetSunbeamGlowRadius: CGFloat = 120
}

extension View {
    /// Map top chrome glass (profile, filter pill, dropdown panel).
    func pushMapControlGlass(
        cornerRadius: CGFloat,
        treatment: PushMapControlTreatment = .standard
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(.ultraThinMaterial, in: shape)
            .background(shape.fill(PushMapGlassTokens.fill))
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
                    .stroke(treatment.reflectiveHighlight, lineWidth: PushMapGlassTokens.highlightWidth)
                    .padding(PushMapGlassTokens.highlightInset)
            }
            .shadow(
                color: PushMapGlassTokens.shadow,
                radius: PushMapGlassTokens.shadowRadius,
                y: PushMapGlassTokens.shadowYOffset
            )
    }
}

private extension PushMapControlTreatment {
    var centerHighlight: AnyShapeStyle {
        switch self {
        case .profileButton:
            return AnyShapeStyle(Color.white.opacity(PushMapGlassTokens.profileCenterOpacity))
        case .standard, .filterPill:
            return AnyShapeStyle(Color.clear)
        }
    }

    var surfaceGlow: AnyShapeStyle {
        switch self {
        case .filterPill:
            return AnyShapeStyle(RadialGradient(
                colors: [
                    PushControlGlassTokens.warmTint.opacity(PushMapGlassTokens.pillCreamGlowOpacity),
                    PushControlColors.activeFill.opacity(PushMapGlassTokens.pillGlowOpacity),
                    .clear
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: PushMapGlassTokens.pillGlowRadius
            ))
        case .profileButton:
            return AnyShapeStyle(RadialGradient(
                colors: [
                    Color.white.opacity(PushMapGlassTokens.profileCoreOpacity),
                    PushControlGlassTokens.warmTint.opacity(PushMapGlassTokens.profileCreamGlowOpacity),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: PushMapGlassTokens.profileGlowRadius
            ))
        case .standard:
            return AnyShapeStyle(Color.clear)
        }
    }

    var outerStroke: AnyShapeStyle {
        switch self {
        case .profileButton:
            return AnyShapeStyle(PushControlColors.activeFill.opacity(PushMapGlassTokens.profileRingOpacity))
        case .standard, .filterPill:
            return AnyShapeStyle(PushMapGlassTokens.stroke)
        }
    }

    var reflectiveHighlight: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(
            colors: [
                Color.white.opacity(highlightTopOpacity),
                Color.white.opacity(PushMapGlassTokens.highlightSideOpacity),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        ))
    }

    var strokeWidth: CGFloat {
        self == .profileButton
            ? PushMapGlassTokens.profileRingWidth
            : PushMapGlassTokens.strokeWidth
    }

    private var highlightTopOpacity: Double {
        self == .filterPill
            ? PushMapGlassTokens.pillHighlightOpacity
            : PushMapGlassTokens.highlightOpacity
    }
}

/// Map popup sheet surface treatment (DS-011).
enum MapPopupSheetSurface {
    /// Existing cream-glass over satellite (individual friend / day detail).
    case mapGlass
    /// Warmer solid cream for multi-person Friends-row sheets (Issue #139).
    case solidCream
}

/// Shared map popup surface for friend detail and calendar day sheets.
struct MapPopupSheetBackground<S: Shape>: View {
    let shape: S
    var surface: MapPopupSheetSurface = .mapGlass

    var body: some View {
        switch surface {
        case .mapGlass:
            mapGlassBody
        case .solidCream:
            solidCreamBody
        }
    }

    private var mapGlassBody: some View {
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(PushMapGlassTokens.sheetCreamFill)
            shape.fill(sunbeamAccent)
            shape.stroke(
                PushMapGlassTokens.sheetStroke,
                lineWidth: PushMapGlassTokens.sheetStrokeWidth
            )
            shape
                .stroke(
                    reflectiveHighlight,
                    lineWidth: PushMapGlassTokens.sheetHighlightWidth
                )
                .padding(PushMapGlassTokens.sheetHighlightInset)
        }
    }

    private var solidCreamBody: some View {
        ZStack {
            shape.fill(PushCreamTokens.solidCard)
            shape.stroke(
                PushColorPalette.Accent.walnut.opacity(PushCreamTokens.solidCardStrokeOpacity),
                lineWidth: PushCreamTokens.solidCardStrokeWidth
            )
        }
        .shadow(
            color: PushMapGlassTokens.shadow,
            radius: PushMapGlassTokens.shadowRadius,
            y: PushMapGlassTokens.shadowYOffset
        )
    }

    private var sunbeamAccent: RadialGradient {
        RadialGradient(
            colors: [
                PushControlGlassTokens.warmTint.opacity(PushMapGlassTokens.sheetCreamGlowOpacity),
                PushControlColors.activeFill.opacity(PushMapGlassTokens.sheetSunbeamGlowOpacity),
                .clear
            ],
            center: .bottom,
            startRadius: 0,
            endRadius: PushMapGlassTokens.sheetSunbeamGlowRadius
        )
    }

    private var reflectiveHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(PushMapGlassTokens.sheetHighlightTopOpacity),
                Color.white.opacity(PushMapGlassTokens.sheetHighlightSideOpacity),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension MapPopupSheetBackground where S == Rectangle {
    init(surface: MapPopupSheetSurface = .mapGlass) {
        self.init(shape: Rectangle(), surface: surface)
    }
}
