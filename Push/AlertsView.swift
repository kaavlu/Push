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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let actionError = viewModel.actionError {
                ActionErrorBanner(
                    message: actionError.message,
                    onRetry: { Task { await viewModel.retryLastAction() } },
                    onDismiss: { viewModel.dismissActionError() }
                )
                .padding(.horizontal, FriendsLayout.horizontalPadding(layout))
                .padding(.bottom, FriendsLayout.bottomPadding(layout))
            }
        }
    }

    private var header: some View {
        PushCreamPageHeader(title: "Alerts", subtitle: "What needs your attention") {
            PushCircleIconButton(
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
            if viewModel.requests.isEmpty && viewModel.groupInvites.isEmpty {
                AlertsStateView.empty
            } else {
                requestList
            }
        }
    }

    private var requestList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: FriendsLayout.listSpacing) {
                if !viewModel.requests.isEmpty {
                    FriendsSectionHeader(
                        title: AlertsCopy.sectionTitle,
                        count: viewModel.requests.count
                    )
                    .padding(.top, AlertsLayout.contentTopSpacing)

                    ForEach(viewModel.requests) { request in
                        requestCard(for: request)
                    }
                }

                if !viewModel.groupInvites.isEmpty {
                    FriendsSectionHeader(
                        title: AlertsCopy.groupSectionTitle,
                        count: viewModel.groupInvites.count
                    )
                    .padding(.top, viewModel.requests.isEmpty ? AlertsLayout.contentTopSpacing : AlertsLayout.sectionTopSpacing)

                    ForEach(viewModel.groupInvites) { invite in
                        GroupRequestCard(
                            invite: invite,
                            phase: viewModel.phase(for: invite.id),
                            isResolving: viewModel.resolvingIDs.contains(invite.id),
                            onAccept: { Task { await viewModel.acceptGroupInvite(invite) } },
                            onDeny: { Task { await viewModel.denyGroupInvite(invite) } }
                        )
                    }
                }
            }
            .padding(.bottom, FriendsLayout.bottomPadding(layout))
            .animation(
                .easeInOut(duration: AlertsLayout.removeDuration),
                value: viewModel.requests.map(\.id)
            )
            .animation(
                .easeInOut(duration: AlertsLayout.removeDuration),
                value: viewModel.groupInvites.map(\.id)
            )
        }
        .refreshable {
            await viewModel.refresh()
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
                AlertAddedBadge()
            } else {
                HStack(spacing: AlertsLayout.actionSpacing) {
                    AlertActionButton(
                        title: "Deny",
                        style: .deny,
                        disabled: isResolving,
                        accessibilityLabel: "Deny friend request from \(name)",
                        action: { Task { await viewModel.deny(request) } }
                    )
                    AlertActionButton(
                        title: "Accept",
                        style: .accept,
                        disabled: isResolving,
                        accessibilityLabel: "Accept friend request from \(name)",
                        action: { Task { await viewModel.accept(request) } }
                    )
                }
            }
        }
        .animation(
            .easeInOut(duration: AlertsLayout.addedTransitionDuration),
            value: phase
        )
    }
}

// MARK: - States (DS-071 EmptySurface family)

private enum AlertsStateView {
    static var loading: some View {
        EmptySurfaceStateView.loading(message: EmptySurfaceCopy.alertsLoading)
    }

    /// Restrained empty — title only via EmptySurface (no fake list rows).
    static var empty: some View {
        EmptySurfaceView(
            title: EmptySurfaceCopy.alertsEmptyTitle,
            systemImage: "bell",
            expandsVertically: true
        )
    }

    static func error(retry: @escaping () -> Void) -> some View {
        EmptySurfaceStateView.failed(
            surface: EmptySurfaceCopy.alertsSurfaceName,
            retry: retry
        )
    }
}

#if DEBUG
struct AlertsView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix { AlertsView() }
    }
}
#endif
