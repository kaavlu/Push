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

            VStack(spacing: FriendsLayout.screenStackSpacing(layout)) {
                header
                content
            }
            .padding(.horizontal, FriendsLayout.horizontalPadding(layout))
            .padding(.top, FriendsLayout.topPadding)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: FriendsLayout.headerSubtitleSpacing) {
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
            LazyVStack(alignment: .leading, spacing: FriendsLayout.listSpacing) {
                FriendsSectionHeader(
                    title: AlertsCopy.sectionTitle,
                    count: viewModel.requests.count
                )
                .padding(.top, AlertsLayout.contentTopSpacing)

                ForEach(viewModel.requests) { request in
                    requestCard(for: request)
                }
            }
            .padding(.bottom, FriendsLayout.bottomPadding(layout))
            .animation(
                .easeInOut(duration: AlertsLayout.removeDuration),
                value: viewModel.requests.map(\.id)
            )
        }
    }

    private func requestCard(for request: FriendRequestAlertModel) -> some View {
        let phase = viewModel.phase(for: request.id)
        let isDenying = phase == .denying

        return FriendRowCard(
            row: request.row,
            showsGroupLabel: false,
            showsStatusDetail: true,
            usesAvailabilityAppearance: false,
            customTrailing: AnyView(trailing(for: request, phase: phase))
        )
        .opacity(isDenying ? 0 : 1)
        .scaleEffect(isDenying ? 0.96 : 1, anchor: .center)
        .animation(
            .easeOut(duration: AlertsLayout.denyCollapseDuration),
            value: isDenying
        )
        .transition(
            .asymmetric(
                insertion: .opacity,
                removal: .opacity.combined(with: .move(edge: .top))
            )
        )
    }

    @ViewBuilder
    private func trailing(for request: FriendRequestAlertModel, phase: AlertCardPhase?) -> some View {
        let isResolving = viewModel.resolvingIDs.contains(request.id)
        let name = request.request.requester.displayName

        Group {
            if phase == .added {
                addedBadge
            } else {
                HStack(spacing: AlertsLayout.actionSpacing) {
                    actionButton(
                        "Deny",
                        requesterName: name,
                        style: .deny,
                        disabled: isResolving
                    ) {
                        Task { await viewModel.deny(request) }
                    }
                    actionButton(
                        "Accept",
                        requesterName: name,
                        style: .accept,
                        disabled: isResolving
                    ) {
                        Task { await viewModel.accept(request) }
                    }
                }
            }
        }
        .animation(
            .easeInOut(duration: AlertsLayout.addedTransitionDuration),
            value: phase
        )
    }

    private var addedBadge: some View {
        Text(AlertsCopy.addedLabel)
            .font(.caption.weight(.bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .padding(.horizontal, AlertsLayout.actionHorizontalPadding)
            .padding(.vertical, AlertsLayout.actionVerticalPadding)
            .background(
                PushColorPalette.Accent.mintFoam.opacity(AlertsColor.addedFillOpacity),
                in: Capsule()
            )
            .accessibilityLabel(AlertsCopy.addedLabel)
    }

    private enum ActionStyle {
        case accept
        case deny
    }

    private func actionButton(
        _ title: String,
        requesterName: String,
        style: ActionStyle,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(minWidth: AlertsLayout.actionMinWidth)
                .padding(.horizontal, AlertsLayout.actionHorizontalPadding)
                .padding(.vertical, AlertsLayout.actionVerticalPadding)
                .background(actionBackground(style), in: Capsule())
                .overlay {
                    if style == .deny {
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

    private func actionBackground(_ style: ActionStyle) -> Color {
        switch style {
        case .accept:
            return PushControlColors.activeFill
        case .deny:
            return FriendsColor.cardCream.opacity(AlertsColor.denyFillOpacity)
        }
    }
}

// MARK: - States

private enum AlertsStateView {
    static var loading: some View {
        VStack(spacing: AlertsLayout.stateSpacing) {
            ProgressView()
                .tint(PushControlColors.activeForeground)
            Text("Checking alerts")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    /// Restrained empty state — title only, centered on the cream page.
    static var empty: some View {
        Text(AlertsCopy.emptyTitle)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PushControlColors.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, AlertsLayout.stateHorizontalPadding)
            .padding(.top, AlertsLayout.contentTopSpacing)
    }

    static func error(retry: @escaping () -> Void) -> some View {
        VStack(spacing: AlertsLayout.stateSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: AlertsLayout.stateIconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textSecondary)
            Text("Couldn't load alerts")
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text("Try again in a moment.")
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(PushControlColors.activeFill)
                .foregroundStyle(PushControlColors.activeForeground)
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
