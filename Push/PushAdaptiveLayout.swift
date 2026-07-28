//
//  PushAdaptiveLayout.swift
//  Push
//
//  Shared semantic layout metrics for width-aware iPhone layouts.
//

import SwiftUI

enum PushLayoutTier: String, CaseIterable {
    case compact
    case standard
    case large
}

struct PushAdaptiveLayout: Equatable {
    let containerWidth: CGFloat
    let tier: PushLayoutTier

    init(containerWidth: CGFloat) {
        self.containerWidth = containerWidth
        if containerWidth < Self.standardWidth {
            tier = .compact
        } else if containerWidth < Self.largeWidth {
            tier = .standard
        } else {
            tier = .large
        }
    }

    static let reference = PushAdaptiveLayout(containerWidth: 430)

    private static let standardWidth: CGFloat = 380
    private static let largeWidth: CGFloat = 420

    func value(compact: CGFloat, standard: CGFloat, large: CGFloat) -> CGFloat {
        switch tier {
        case .compact: return compact
        case .standard: return standard
        case .large: return large
        }
    }

    func size(compact: CGSize, standard: CGSize, large: CGSize) -> CGSize {
        switch tier {
        case .compact: return compact
        case .standard: return standard
        case .large: return large
        }
    }

    var pageHorizontalPadding: CGFloat { value(compact: 14, standard: 16, large: 18) }
    var modalHorizontalPadding: CGFloat { value(compact: 16, standard: 18, large: 20) }
    var cardPadding: CGFloat { value(compact: 12, standard: 14, large: 16) }
    var denseCardPadding: CGFloat { value(compact: 12, standard: 13, large: 15) }
    var cardCornerRadius: CGFloat { value(compact: 22, standard: 24, large: 26) }
    var sectionSpacing: CGFloat { value(compact: 14, standard: 16, large: 18) }
    var rowSpacing: CGFloat { value(compact: 9, standard: 11, large: 13) }
    var controlSize: CGFloat { value(compact: 44, standard: 44, large: 44) }
    var primaryButtonHeight: CGFloat { value(compact: 50, standard: 52, large: 54) }
    var avatarSmall: CGFloat { value(compact: 44, standard: 48, large: 52) }
    var avatarMedium: CGFloat { value(compact: 56, standard: 62, large: 68) }
    var avatarLarge: CGFloat { value(compact: 96, standard: 104, large: 112) }
    var iconCircle: CGFloat { value(compact: 32, standard: 34, large: 38) }
    /// Floating bottom nav clearance from the home-indicator safe area.
    var bottomOverlayMargin: CGFloat { value(compact: 6, standard: 8, large: 10) }
    var bottomContentPadding: CGFloat { value(compact: 82, standard: 92, large: 110) }
    var puckScale: CGFloat { value(compact: 0.90, standard: 0.95, large: 1.0) }
    var onboardingTopInset: CGFloat { value(compact: 72, standard: 92, large: 112) }
}

private struct PushAdaptiveLayoutKey: EnvironmentKey {
    static let defaultValue = PushAdaptiveLayout.reference
}

extension EnvironmentValues {
    var pushLayout: PushAdaptiveLayout {
        get { self[PushAdaptiveLayoutKey.self] }
        set { self[PushAdaptiveLayoutKey.self] = newValue }
    }
}

struct PushAdaptiveLayoutReader<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            content
                .environment(\.pushLayout, PushAdaptiveLayout(containerWidth: proxy.size.width))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

#if DEBUG
enum PushPreviewDevice: String, CaseIterable, Identifiable {
    case small = "iPhone SE (3rd generation)"
    case standard = "iPhone 15"
    case pro = "iPhone 17 Pro"
    case proMax = "iPhone 17 Pro Max"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Small iPhone"
        case .standard: return "Standard iPhone"
        case .pro: return "iPhone 17 Pro"
        case .proMax: return "iPhone 17 Pro Max"
        }
    }
}

struct PushPreviewMatrix<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        ForEach(PushPreviewDevice.allCases) { device in
            PushAdaptiveLayoutReader {
                content()
            }
            .previewDevice(PreviewDevice(rawValue: device.rawValue))
            .previewDisplayName(device.displayName)
        }
    }
}
#endif
