import SwiftUI

struct AddFriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout
    @StateObject private var viewModel: AddFriendsViewModel

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: AddFriendsViewModel())
    }

    @MainActor
    init(viewModel: AddFriendsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            FriendsBackground()
            VStack(spacing: AddFriendsLayout.stackSpacing) {
                header
                searchField
                if let actionError = viewModel.actionError {
                    ActionErrorBanner(
                        message: actionError.message,
                        onRetry: { Task { await viewModel.retryLastAction() } },
                        onDismiss: { viewModel.dismissActionError() }
                    )
                }
                content
            }
            .padding(.horizontal, AddFriendsLayout.horizontalPadding(layout))
            .padding(.top, AddFriendsLayout.topPadding)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: AddFriendsLayout.headerSpacing) {
                Text("Add Friends")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                Text("Find people on Push")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PushControlColors.inactiveForeground)
            }
            Spacer(minLength: 0)
            FriendsCircleButton(
                systemImageName: "xmark",
                accessibilityLabel: "Close add friends",
                action: { dismiss() }
            )
        }
    }

    private var searchField: some View {
        FriendsSearchField(
            text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.onSearchTextChanged($0) }
            ),
            placeholder: "Search by name or username"
        )
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.contentState {
        case .prompt:
            AddFriendsStateView.prompt
        case .loading:
            AddFriendsStateView.loading
        case .noResults:
            AddFriendsStateView.noResults
        case .failed:
            AddFriendsStateView.error {
                Task { await viewModel.retry() }
            }
        case .results(let rows):
            resultsList(rows)
        }
    }

    private func resultsList(_ rows: [AddFriendRowModel]) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: AddFriendsLayout.listSpacing) {
                ForEach(rows) { row in
                    FriendRowCard(
                        row: row.row,
                        showsGroupLabel: false,
                        fixedHeight: AddFriendsLayout.cardHeight,
                        usesAvailabilityAppearance: false,
                        customTrailing: AnyView(actions(for: row))
                    )
                }
            }
            .padding(.bottom, AddFriendsLayout.bottomPadding(layout))
        }
    }

    @ViewBuilder
    private func actions(for row: AddFriendRowModel) -> some View {
        let isActing = viewModel.actingIDs.contains(row.id)
        switch row.relation {
        case .none:
            actionButton("Add Friend", isPrimary: true, disabled: isActing) {
                Task { await viewModel.sendRequest(to: row) }
            }
        case .outgoingPending:
            actionButton("Cancel", isPrimary: false, disabled: isActing) {
                Task { await viewModel.cancelRequest(for: row) }
            }
        case .incomingPending:
            HStack(spacing: AddFriendsLayout.actionSpacing) {
                actionButton("Decline", isPrimary: false, disabled: isActing) {
                    Task { await viewModel.deny(row: row) }
                }
                actionButton("Accept", isPrimary: true, disabled: isActing) {
                    Task { await viewModel.accept(row: row) }
                }
            }
        case .friends:
            actionButton("Friends", isPrimary: false, disabled: true, action: {})
        }
    }

    private func actionButton(
        _ title: String,
        isPrimary: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(
                    isPrimary ? PushControlColors.activeForeground : PushControlColors.textSecondary
                )
                .padding(.horizontal, AddFriendsLayout.actionHorizontalPadding)
                .padding(.vertical, AddFriendsLayout.actionVerticalPadding)
                .background(
                    isPrimary ? PushControlColors.activeFill : FriendsColor.cardCream,
                    in: Capsule()
                )
                .overlay {
                    if !isPrimary {
                        Capsule().stroke(
                            PushColorPalette.Accent.walnut.opacity(AddFriendsColor.denyStrokeOpacity),
                            lineWidth: AddFriendsLayout.actionStrokeWidth
                        )
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? AddFriendsColor.disabledOpacity : 1)
        .accessibilityLabel(title)
    }
}

/// Lightweight search field without the Friends-screen “add” trailing control.
private struct FriendsSearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: FriendsLayout.searchSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: FriendsLayout.searchIconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textSecondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(PushControlColors.textEspresso)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: FriendsLayout.searchIconSize, weight: .semibold))
                        .foregroundStyle(PushControlColors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, FriendsLayout.searchHorizontalPadding)
        .padding(.vertical, FriendsLayout.searchVerticalPadding)
        .background {
            RoundedRectangle(cornerRadius: FriendsLayout.searchCornerRadius, style: .continuous)
                .fill(FriendsColor.cardCream)
            RoundedRectangle(cornerRadius: FriendsLayout.searchCornerRadius, style: .continuous)
                .stroke(
                    PushColorPalette.Accent.walnut.opacity(0.18),
                    lineWidth: 0.9
                )
        }
    }
}

private enum AddFriendsStateView {
    static var prompt: some View {
        state(
            symbol: "person.badge.plus",
            title: "Search for friends",
            message: "Try a name or username to find people on Push."
        ) { EmptyView() }
    }

    static var loading: some View {
        state(symbol: "magnifyingglass", title: "Searching", message: "One moment…") {
            ProgressView().tint(PushControlColors.activeForeground)
        }
    }

    static var noResults: some View {
        state(
            symbol: "person.slash",
            title: "No people found",
            message: "Check the spelling or try a different name."
        ) { EmptyView() }
    }

    static func error(retry: @escaping () -> Void) -> some View {
        state(
            symbol: "exclamationmark.triangle",
            title: "Couldn't search",
            message: "Try again in a moment."
        ) {
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
                .tint(PushControlColors.activeFill)
                .foregroundStyle(PushControlColors.activeForeground)
        }
    }

    private static func state<Accessory: View>(
        symbol: String,
        title: String,
        message: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        VStack(spacing: AddFriendsLayout.stateSpacing) {
            Image(systemName: symbol)
                .font(.system(size: AddFriendsLayout.stateIconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textSecondary)
            Text(title).font(.headline).foregroundStyle(PushControlColors.textEspresso)
            Text(message).font(.subheadline).foregroundStyle(PushControlColors.textSecondary)
            accessory()
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, AddFriendsLayout.stateHorizontalPadding)
    }
}

#if DEBUG
struct AddFriendsView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix { AddFriendsView() }
    }
}
#endif
