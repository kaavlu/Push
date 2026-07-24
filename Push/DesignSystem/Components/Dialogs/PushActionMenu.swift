//
//  PushActionMenu.swift
//  Push
//
//  DS-090 companion — multi-action cream menu (overflow Remove/Block, etc.).
//  Replaces system Menu popovers for branded action lists.
//

import SwiftUI

// MARK: - Models

enum PushActionMenuRole: Equatable {
    case standard
    case destructive
}

struct PushActionMenuItem: Identifiable, Equatable {
    let id: String
    let title: String
    var role: PushActionMenuRole = .standard

    init(id: String, title: String, role: PushActionMenuRole = .standard) {
        self.id = id
        self.title = title
        self.role = role
    }
}

struct PushActionMenuConfig: Equatable {
    var title: String? = nil
    var items: [PushActionMenuItem]
    var cancelTitle: String = "Cancel"
}

// MARK: - Content

/// Cream card listing actions + cancel. Destructive rows use danger color text.
struct PushActionMenuDialog: View {
    @Environment(\.pushLayout) private var layout

    let config: PushActionMenuConfig
    let onSelect: (PushActionMenuItem) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: PushActionMenuLayout.sectionSpacing) {
            if let title = config.title, !title.isEmpty {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(spacing: PushActionMenuLayout.itemSpacing) {
                ForEach(config.items) { item in
                    actionButton(item)
                }
            }

            Button(action: onCancel) {
                Text(config.cancelTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PushControlColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: PushActionMenuLayout.cancelHitHeight)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(config.cancelTitle)
        }
        .padding(PushActionMenuLayout.cardPadding)
        .frame(maxWidth: PushActionMenuLayout.maxCardWidth)
        .pushSolidCreamCard(cornerRadius: PushRadiusTokens.card(layout))
        .accessibilityElement(children: .contain)
    }

    private func actionButton(_ item: PushActionMenuItem) -> some View {
        Button {
            onSelect(item)
        } label: {
            Text(item.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(foreground(for: item.role))
                .frame(maxWidth: .infinity)
                .frame(height: PushActionMenuLayout.itemHeight)
                .background(background(for: item.role), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
    }

    private func foreground(for role: PushActionMenuRole) -> Color {
        switch role {
        case .destructive:
            return Color.white
        case .standard:
            return PushControlColors.activeForeground
        }
    }

    private func background(for role: PushActionMenuRole) -> Color {
        switch role {
        case .destructive:
            return PushControlColors.destructive
        case .standard:
            return PushControlColors.activeFill
        }
    }
}

// MARK: - Presenter

struct PushActionMenuPresenter: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let config: PushActionMenuConfig
    let onSelect: (PushActionMenuItem) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .opacity(PushOpacityTokens.dialogScrim)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)
                .accessibilityHidden(true)

            PushActionMenuDialog(
                config: config,
                onSelect: onSelect,
                onCancel: onCancel
            )
            .padding(.horizontal, PushActionMenuLayout.horizontalInset)
            .transition(cardTransition)
        }
    }

    private var cardTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .scale(scale: PushActionMenuLayout.presentScale))
    }
}

// MARK: - Layout

enum PushActionMenuLayout {
    static let horizontalInset: CGFloat = 28
    static let maxCardWidth: CGFloat = 340
    static let cardPadding: CGFloat = 22
    static let sectionSpacing: CGFloat = 18
    static let itemSpacing: CGFloat = 10
    static let itemHeight: CGFloat = 50
    static let cancelHitHeight: CGFloat = 44
    static let presentScale: CGFloat = 0.96
}

// MARK: - Previews

#if DEBUG
struct PushActionMenuDialog_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            ZStack {
                PushIvoryPageBackground()
                PushActionMenuPresenter(
                    config: PushActionMenuConfig(
                        title: "More actions",
                        items: [
                            PushActionMenuItem(
                                id: "remove",
                                title: "Remove friend",
                                role: .destructive
                            ),
                            PushActionMenuItem(
                                id: "block",
                                title: "Block",
                                role: .destructive
                            )
                        ]
                    ),
                    onSelect: { _ in },
                    onCancel: {}
                )
            }
        }
    }
}
#endif
