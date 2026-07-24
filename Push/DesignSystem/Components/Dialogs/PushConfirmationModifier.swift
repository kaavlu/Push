//
//  PushConfirmationModifier.swift
//  Push
//
//  DS-090 — window-level presentation bridge + `.pushConfirmation` modifiers.
//  Separate from dialog content so list nesting presents over the full window.
//

import SwiftUI
import UIKit

// MARK: - Full-window presentation bridge

/// Presents over the window (not the local row bounds) so list/scroll nesting works.
struct PushConfirmationOverlayBridge: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let config: PushConfirmationConfig
    var isConfirmLoading: Bool
    var isConfirmDisabled: Bool
    let layout: PushAdaptiveLayout
    let reduceMotion: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> PushConfirmationOverlayAnchor {
        PushConfirmationOverlayAnchor()
    }

    func updateUIViewController(_ anchor: PushConfirmationOverlayAnchor, context: Context) {
        let coordinator = context.coordinator
        coordinator.onConfirm = onConfirm
        coordinator.onCancel = onCancel

        let root = PushConfirmationPresenter(
            config: config,
            isConfirmLoading: isConfirmLoading,
            isConfirmDisabled: isConfirmDisabled,
            onConfirm: { coordinator.onConfirm?() },
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
        var onConfirm: (() -> Void)?
        var onCancel: (() -> Void)?
    }
}

final class PushConfirmationOverlayAnchor: UIViewController {
    override func loadView() {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        self.view = view
    }

    func presentOverlay(_ host: UIViewController, animated: Bool) {
        // Defer until the anchor is in a window (list cells can update early).
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard host.presentingViewController == nil else { return }
            guard let presenter = self.nearestPresenter() else { return }
            presenter.present(host, animated: animated)
        }
    }

    func dismissOverlay(_ host: UIViewController?, animated: Bool) {
        guard let host, host.presentingViewController != nil else { return }
        host.dismiss(animated: animated)
    }

    private func nearestPresenter() -> UIViewController? {
        var candidate: UIViewController? = self
        while let current = candidate {
            if current.view.window != nil {
                var top = current
                while let presented = top.presentedViewController {
                    top = presented
                }
                return top
            }
            candidate = current.parent ?? current.presentingViewController
        }
        return nil
    }
}

// MARK: - View modifiers

private struct PushConfirmationIsPresentedModifier: ViewModifier {
    @Binding var isPresented: Bool
    let config: PushConfirmationConfig
    var isConfirmLoading: Bool
    var isConfirmDisabled: Bool
    let onConfirm: () -> Void
    var onCancel: (() -> Void)?

    @Environment(\.pushLayout) private var layout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.background {
            PushConfirmationOverlayBridge(
                isPresented: $isPresented,
                config: config,
                isConfirmLoading: isConfirmLoading,
                isConfirmDisabled: isConfirmDisabled,
                layout: layout,
                reduceMotion: reduceMotion,
                onConfirm: handleConfirm,
                onCancel: handleCancel
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }

    private func handleConfirm() {
        if !isConfirmLoading {
            isPresented = false
        }
        onConfirm()
    }

    private func handleCancel() {
        isPresented = false
        onCancel?()
    }
}

private struct PushConfirmationItemModifier<Item: Identifiable>: ViewModifier {
    @Binding var item: Item?
    let title: (Item) -> String
    let message: (Item) -> String?
    let confirmTitle: String
    let confirmRole: PushConfirmationRole
    let cancelTitle: String
    var isConfirmLoading: Bool
    var isConfirmDisabled: Bool
    let onConfirm: (Item) -> Void
    var onCancel: (() -> Void)?

    @Environment(\.pushLayout) private var layout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isPresentedBinding: Binding<Bool> {
        Binding(
            get: { item != nil },
            set: { presented in
                if !presented { item = nil }
            }
        )
    }

    private var resolvedConfig: PushConfirmationConfig {
        if let current = item {
            return PushConfirmationConfig(
                title: title(current),
                message: message(current),
                confirmTitle: confirmTitle,
                confirmRole: confirmRole,
                cancelTitle: cancelTitle
            )
        }
        return PushConfirmationConfig(
            title: "",
            confirmTitle: confirmTitle,
            confirmRole: confirmRole,
            cancelTitle: cancelTitle
        )
    }

    func body(content: Content) -> some View {
        content.background {
            PushConfirmationOverlayBridge(
                isPresented: isPresentedBinding,
                config: resolvedConfig,
                isConfirmLoading: isConfirmLoading,
                isConfirmDisabled: isConfirmDisabled,
                layout: layout,
                reduceMotion: reduceMotion,
                onConfirm: handleConfirm,
                onCancel: handleCancel
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }

    private func handleConfirm() {
        guard let current = item else { return }
        if !isConfirmLoading {
            item = nil
        }
        onConfirm(current)
    }

    private func handleCancel() {
        item = nil
        onCancel?()
    }
}

extension View {
    /// Present a Push-styled confirmation over the window.
    func pushConfirmation(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        confirmTitle: String,
        confirmRole: PushConfirmationRole = .destructive,
        cancelTitle: String = "Cancel",
        isConfirmLoading: Bool = false,
        isConfirmDisabled: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        modifier(
            PushConfirmationIsPresentedModifier(
                isPresented: isPresented,
                config: PushConfirmationConfig(
                    title: title,
                    message: message,
                    confirmTitle: confirmTitle,
                    confirmRole: confirmRole,
                    cancelTitle: cancelTitle
                ),
                isConfirmLoading: isConfirmLoading,
                isConfirmDisabled: isConfirmDisabled,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
        )
    }

    /// Present a Push-styled confirmation driven by an optional pending item.
    func pushConfirmation<Item: Identifiable>(
        item: Binding<Item?>,
        title: @escaping (Item) -> String,
        message: @escaping (Item) -> String?,
        confirmTitle: String,
        confirmRole: PushConfirmationRole = .destructive,
        cancelTitle: String = "Cancel",
        isConfirmLoading: Bool = false,
        isConfirmDisabled: Bool = false,
        onConfirm: @escaping (Item) -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        modifier(
            PushConfirmationItemModifier(
                item: item,
                title: title,
                message: message,
                confirmTitle: confirmTitle,
                confirmRole: confirmRole,
                cancelTitle: cancelTitle,
                isConfirmLoading: isConfirmLoading,
                isConfirmDisabled: isConfirmDisabled,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
        )
    }
}
