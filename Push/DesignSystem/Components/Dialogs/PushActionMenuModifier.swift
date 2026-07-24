//
//  PushActionMenuModifier.swift
//  Push
//
//  Window-level presentation for PushActionMenu (same bridge pattern as confirms).
//

import SwiftUI
import UIKit

// MARK: - Bridge

struct PushActionMenuOverlayBridge: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let config: PushActionMenuConfig
    let layout: PushAdaptiveLayout
    let reduceMotion: Bool
    let onSelect: (PushActionMenuItem) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> PushConfirmationOverlayAnchor {
        PushConfirmationOverlayAnchor()
    }

    func updateUIViewController(_ anchor: PushConfirmationOverlayAnchor, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSelect = onSelect
        coordinator.onCancel = onCancel

        let root = PushActionMenuPresenter(
            config: config,
            onSelect: { item in coordinator.onSelect?(item) },
            onCancel: { coordinator.onCancel?() }
        )
        .environment(\.pushLayout, layout)

        if isPresented {
            if let host = coordinator.host {
                host.rootView = AnyView(root)
            } else {
                let host = UIHostingController(rootView: AnyView(root))
                host.modalPresentationStyle = .overFullScreen
                host.modalTransitionStyle = .crossDissolve
                host.view.backgroundColor = .clear
                coordinator.host = host
                anchor.presentOverlay(host, animated: !reduceMotion)
            }
        } else {
            anchor.dismissOverlay(coordinator.host, animated: !reduceMotion)
            coordinator.host = nil
        }
    }

    static func dismantleUIViewController(
        _ anchor: PushConfirmationOverlayAnchor,
        coordinator: Coordinator
    ) {
        anchor.dismissOverlay(coordinator.host, animated: false)
        coordinator.host = nil
    }

    final class Coordinator {
        var host: UIHostingController<AnyView>?
        var onSelect: ((PushActionMenuItem) -> Void)?
        var onCancel: (() -> Void)?
    }
}

// MARK: - Modifier

private struct PushActionMenuIsPresentedModifier: ViewModifier {
    @Binding var isPresented: Bool
    let config: PushActionMenuConfig
    let onSelect: (PushActionMenuItem) -> Void
    var onCancel: (() -> Void)?

    @Environment(\.pushLayout) private var layout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.background {
            PushActionMenuOverlayBridge(
                isPresented: $isPresented,
                config: config,
                layout: layout,
                reduceMotion: reduceMotion,
                onSelect: handleSelect,
                onCancel: handleCancel
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }

    private func handleSelect(_ item: PushActionMenuItem) {
        // Call first so hosts can queue follow-up UI (e.g. confirmation) before dismiss.
        onSelect(item)
        isPresented = false
    }

    private func handleCancel() {
        isPresented = false
        onCancel?()
    }
}

extension View {
    /// Present a Push-styled multi-action menu over the window.
    func pushActionMenu(
        isPresented: Binding<Bool>,
        title: String? = nil,
        items: [PushActionMenuItem],
        cancelTitle: String = "Cancel",
        onSelect: @escaping (PushActionMenuItem) -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        modifier(
            PushActionMenuIsPresentedModifier(
                isPresented: isPresented,
                config: PushActionMenuConfig(
                    title: title,
                    items: items,
                    cancelTitle: cancelTitle
                ),
                onSelect: onSelect,
                onCancel: onCancel
            )
        )
    }
}
