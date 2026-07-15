import SwiftUI

struct AlertsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout
    @StateObject private var viewModel: AlertsViewModel

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: AlertsViewModel())
    }

    @MainActor
    init(viewModel: AlertsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            FriendsBackground()
            content
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .padding(.horizontal, AlertsLayout.horizontalPadding(layout))
                .padding(.top, AlertsLayout.topPadding)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: AlertsLayout.headerSpacing) {
                Text("Alerts")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                Text("What needs your attention")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PushControlColors.inactiveForeground)
            }
            Spacer(minLength: 0)
            FriendsCircleButton(
                systemImageName: "xmark",
                accessibilityLabel: "Close alerts",
                action: { dismiss() }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            AlertsStateView.loading
        case .failed:
            AlertsStateView.error { Task { await viewModel.load() } }
        case .loaded:
            if viewModel.requests.isEmpty {
                AlertsStateView.empty
            } else {
                requestList
            }
        }
    }

    private var requestList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: AlertsLayout.listSpacing) {
                ForEach(viewModel.requests) { request in
                    FriendRowCard(
                        row: request.row,
                        showsGroupLabel: false,
                        fixedHeight: AlertsLayout.cardHeight,
                        usesAvailabilityAppearance: false,
                        customTrailing: AnyView(actions(for: request))
                    )
                }
            }
            .padding(.horizontal, AlertsLayout.horizontalPadding(layout))
            .padding(.bottom, AlertsLayout.bottomPadding(layout))
        }
    }

    private func actions(for request: FriendRequestAlertModel) -> some View {
        let isResolving = viewModel.resolvingIDs.contains(request.id)
        return HStack(spacing: AlertsLayout.actionSpacing) {
            actionButton("Deny", requesterName: request.request.requester.displayName, isPrimary: false, disabled: isResolving) {
                Task { await viewModel.deny(request) }
            }
            actionButton("Accept", requesterName: request.request.requester.displayName, isPrimary: true, disabled: isResolving) {
                Task { await viewModel.accept(request) }
            }
        }
    }

    private func actionButton(
        _ title: String, requesterName: String, isPrimary: Bool, disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(isPrimary ? PushControlColors.activeForeground : PushControlColors.textSecondary)
                .padding(.horizontal, AlertsLayout.actionHorizontalPadding)
                .padding(.vertical, AlertsLayout.actionVerticalPadding)
                .background(isPrimary ? PushControlColors.activeFill : FriendsColor.cardCream, in: Capsule())
                .overlay {
                    if !isPrimary {
                        Capsule().stroke(
                            PushColorPalette.Accent.walnut.opacity(AlertsColor.denyStrokeOpacity),
                            lineWidth: AlertsLayout.actionStrokeWidth
                        )
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? AlertsColor.disabledOpacity : 1)
        .accessibilityLabel("\(title) friend request from \(requesterName)")
    }
}

private enum AlertsStateView {
    static var loading: some View {
        state(symbol: "bell", title: "Checking alerts", message: "One moment…") {
            ProgressView().tint(PushControlColors.activeForeground)
        }
    }

    static var empty: some View {
        state(symbol: "bell.badge", title: "You're all caught up", message: "New friend requests will show up here.") {
            EmptyView()
        }
    }

    static func error(retry: @escaping () -> Void) -> some View {
        state(symbol: "exclamationmark.triangle", title: "Couldn't load alerts", message: "Try again in a moment.") {
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(PushControlColors.activeFill)
                .foregroundStyle(PushControlColors.activeForeground)
        }
    }

    private static func state<Accessory: View>(
        symbol: String, title: String, message: String, @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        VStack(spacing: AlertsLayout.stateSpacing) {
            Image(systemName: symbol)
                .font(.system(size: AlertsLayout.stateIconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textSecondary)
            Text(title).font(.headline).foregroundStyle(PushControlColors.textEspresso)
            Text(message).font(.subheadline).foregroundStyle(PushControlColors.textSecondary)
            accessory()
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, AlertsLayout.stateHorizontalPadding)
    }
}

#if DEBUG
struct AlertsView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix { AlertsView() }
    }
}
#endif
