//
//  PushCreamSurfaces.swift
//  Push
//
//  DS-014 / DS-017 — ivory page + solid cream list-card foundation.
//

import SwiftUI

/// Semantic cream roles for ivory-page destinations (DS-014).
/// Glass-card cream roles live in `PushGlassCreamTokens` (preserve Plans glass look).
enum PushCreamTokens {
    static let pageIvory = Color(red: 0.988, green: 0.964, blue: 0.902)
    static let solidCard = Color(red: 1.0, green: 0.992, blue: 0.955)
    static let solidCardMutedOpacity = 0.58
    static let solidCardStrokeOpacity = 0.18
    static let solidCardStrokeWidth: CGFloat = 0.8
    static let ringOpacity = 0.9
    static let neutralRingOpacity = 0.28

    /// Metadata browns shared by Plans chrome (not solid-card fill).
    static let metadata = Color(red: 0.43, green: 0.29, blue: 0.17)
    static let metadataSecondary = Color(red: 0.55, green: 0.43, blue: 0.31)
    static let metadataTertiary = Color(red: 0.68, green: 0.58, blue: 0.47)
}

/// Flat ivory page for persistent cream destinations (Friends, Plans, Alerts, …).
struct PushIvoryPageBackground: View {
    var body: some View {
        PushCreamTokens.pageIvory
            .ignoresSafeArea()
    }
}

extension View {
    /// Solid cream list-card foundation: opaque fill + subtle walnut border.
    /// Use for person/group/request/history rows and inline error banners on ivory.
    func pushSolidCreamCard(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(PushCreamTokens.solidCard)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    PushColorPalette.Accent.walnut.opacity(PushCreamTokens.solidCardStrokeOpacity),
                    lineWidth: PushCreamTokens.solidCardStrokeWidth
                )
        }
    }
}

// MARK: - Migration shims

/// Prefer `PushIvoryPageBackground`.
typealias FriendsBackground = PushIvoryPageBackground

extension View {
    /// Prefer `pushSolidCreamCard(cornerRadius:)`.
    func friendsCard(cornerRadius: CGFloat) -> some View {
        pushSolidCreamCard(cornerRadius: cornerRadius)
    }
}

#if DEBUG
struct PushCreamSurfaces_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            ZStack {
                PushIvoryPageBackground()
                Text("Solid cream card")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .pushSolidCreamCard(cornerRadius: 20)
                    .padding()
            }
        }
    }
}
#endif
