//
//  RegionalActivityPuck.swift
//  Push
//

import SwiftUI

struct RegionalActivityPuck: View {
    let model: RegionalPuckModel
    @State private var isPulsing = false

    private var size: CGFloat {
        switch model.memberCount {
        case 2...5: return RegionalActivityPuckLayout.sizeSmall
        case 6...15: return RegionalActivityPuckLayout.sizeMedium
        case 16...35: return RegionalActivityPuckLayout.sizeLarge
        case 36...75: return RegionalActivityPuckLayout.sizeXLarge
        default: return RegionalActivityPuckLayout.sizeXXLarge
        }
    }

    private var pulseColor: Color {
        model.containsCurrentUser || model.containsJoinedGroup
            ? RegionalActivityPuckColor.joinedPulse
            : PushColorPalette.Accent.sunbeam
    }

    var body: some View {
        ZStack {
            pulseRing
            activityCore
            VStack(spacing: RegionalActivityPuckLayout.contentSpacing) {
                locationInitialsLabel
                countLabel
            }
        }
        .frame(
            width: size * RegionalActivityPuckLayout.frameScale,
            height: size * RegionalActivityPuckLayout.frameScale
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.memberCount) friends active near \(model.regionName)")
        .onAppear {
            withAnimation(
                .easeInOut(duration: RegionalActivityPuckLayout.pulseDuration)
                .repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
    }

    private var pulseRing: some View {
        Circle()
            .stroke(
                pulseColor.opacity(RegionalActivityPuckLayout.pulseOpacity),
                lineWidth: model.containsCurrentUser
                    ? RegionalActivityPuckLayout.selfPulseLineWidth
                    : RegionalActivityPuckLayout.pulseLineWidth
            )
            .frame(width: size, height: size)
            .scaleEffect(isPulsing ? RegionalActivityPuckLayout.pulseMaxScale : RegionalActivityPuckLayout.pulseMinScale)
            .opacity(isPulsing ? RegionalActivityPuckLayout.pulseLowOpacity : RegionalActivityPuckLayout.pulseHighOpacity)
    }

    private var activityCore: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay {
                Circle()
                    .fill(PushColorPalette.Accent.sunbeam.opacity(coreTintOpacity))
            }
            .overlay {
                Circle()
                    .stroke(PushColorPalette.Accent.walnut, lineWidth: RegionalActivityPuckLayout.coreStrokeWidth)
            }
            .shadow(
                color: PushColorPalette.Accent.walnut.opacity(RegionalActivityPuckLayout.shadowOpacity),
                radius: RegionalActivityPuckLayout.shadowRadius,
                y: RegionalActivityPuckLayout.shadowYOffset
            )
            .frame(width: size, height: size)
    }

    private var coreTintOpacity: Double {
        RegionalActivityPuckLayout.coreTintBaseOpacity
            + model.activityScore * RegionalActivityPuckLayout.coreTintScoreMultiplier
    }

    private var countLabel: some View {
        Text("\(model.memberCount)")
            .font(.system(size: countFontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(PushColorPalette.Accent.walnut)
            .lineLimit(1)
            .minimumScaleFactor(RegionalActivityPuckLayout.minimumTextScale)
    }

    private var locationInitialsLabel: some View {
        Text(locationInitials)
            .font(.system(size: initialsFontSize, weight: .black, design: .rounded))
            .foregroundStyle(PushColorPalette.Accent.walnut)
            .lineLimit(1)
            .minimumScaleFactor(RegionalActivityPuckLayout.minimumTextScale)
            .padding(.horizontal, RegionalActivityPuckLayout.initialsHorizontalPadding)
            .padding(.vertical, RegionalActivityPuckLayout.initialsVerticalPadding)
            .background {
                Capsule()
                    .fill(.white.opacity(RegionalActivityPuckLayout.initialsPlateOpacity))
            }
    }

    private var locationInitials: String {
        if isSanFranciscoCoordinate {
            return "SF"
        }
        let words = model.regionName
            .split(separator: " ")
            .prefix(RegionalActivityPuckLayout.initialsLimit)
        let initials = words.compactMap(\.first).map(String.init).joined()
        return initials.isEmpty ? "NE" : initials.uppercased()
    }

    private var isSanFranciscoCoordinate: Bool {
        model.coordinate.latitude >= RegionalActivityPuckLayout.sfMinLatitude
            && model.coordinate.latitude <= RegionalActivityPuckLayout.sfMaxLatitude
            && model.coordinate.longitude >= RegionalActivityPuckLayout.sfMinLongitude
            && model.coordinate.longitude <= RegionalActivityPuckLayout.sfMaxLongitude
    }

    private var countFontSize: CGFloat {
        min(
            RegionalActivityPuckLayout.maxCountFontSize,
            size * RegionalActivityPuckLayout.countFontSizeRatio
        )
    }

    private var initialsFontSize: CGFloat {
        min(
            RegionalActivityPuckLayout.maxInitialsFontSize,
            size * RegionalActivityPuckLayout.initialsFontSizeRatio
        )
    }
}

private enum RegionalActivityPuckColor {
    static let joinedPulse = Color(red: 0.94, green: 0.79, blue: 0.48)
}

private enum RegionalActivityPuckLayout {
    static let sizeSmall: CGFloat = 48
    static let sizeMedium: CGFloat = 60
    static let sizeLarge: CGFloat = 74
    static let sizeXLarge: CGFloat = 88
    static let sizeXXLarge: CGFloat = 96
    static let frameScale: CGFloat = 1.55
    static let contentSpacing: CGFloat = 2

    static let pulseOpacity = 0.68
    static let pulseLineWidth: CGFloat = 2.3
    static let selfPulseLineWidth: CGFloat = 3
    static let pulseDuration = 2.2
    static let pulseMinScale: CGFloat = 0.96
    static let pulseMaxScale: CGFloat = 1.16
    static let pulseHighOpacity = 0.56
    static let pulseLowOpacity = 0.14

    static let coreTintBaseOpacity = 0.28
    static let coreTintScoreMultiplier = 0.3
    static let coreStrokeWidth: CGFloat = 2.2
    static let shadowOpacity = 0.22
    static let shadowRadius: CGFloat = 18
    static let shadowYOffset: CGFloat = 8

    static let countFontSizeRatio: CGFloat = 0.32
    static let maxCountFontSize: CGFloat = 30
    static let initialsFontSizeRatio: CGFloat = 0.28
    static let maxInitialsFontSize: CGFloat = 24
    static let minimumTextScale = 0.72

    static let initialsLimit = 2
    static let initialsHorizontalPadding: CGFloat = 6
    static let initialsVerticalPadding: CGFloat = 2
    static let initialsPlateOpacity = 0.52
    static let sfMinLatitude = 37.60
    static let sfMaxLatitude = 37.86
    static let sfMinLongitude = -122.56
    static let sfMaxLongitude = -122.30
}
