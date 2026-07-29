//
//  CreatePostFlowView.swift
//  Push
//
//  Full-screen Feed create-post container: hub → (scratch friends) → compose
//  via NavigationStack (push from right / pop to right, interactive swipe-back).
//

import SwiftUI

/// Stack destinations for Share a Moment (hub is the root).
enum CreatePostRoute: Hashable {
    case selectFriends
    case compose
}

struct CreatePostFlowView: View {
    @StateObject private var viewModel: CreatePostViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout
    /// Drives system navigation transitions + interactive edge swipe.
    @State private var path: [CreatePostRoute] = []

    @MainActor
    init(viewModel: CreatePostViewModel? = nil) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
            // Deep-link launches (e.g. Feed … → edit moment) start past the hub.
            _path = State(initialValue: Self.desiredPath(for: viewModel))
        } else {
            _viewModel = StateObject(wrappedValue: CreatePostViewModel())
            _path = State(initialValue: [])
        }
    }

    var body: some View {
        // Background lives inside each stack root (Profile pattern). A gradient
        // behind NavigationStack is covered by the stack’s opaque system fill.
        NavigationStack(path: $path) {
            hubRoot
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: CreatePostRoute.self) { route in
                    switch route {
                    case .selectFriends:
                        selectFriendsRoot
                            .navigationBarBackButtonHidden(true)
                            .toolbar(.hidden, for: .navigationBar)
                    case .compose:
                        composeRoot
                            .navigationBarBackButtonHidden(true)
                            .toolbar(.hidden, for: .navigationBar)
                    }
                }
        }
        // Keep path and view-model screen in sync (button + swipe pop).
        .onChange(of: viewModel.screen) { _ in
            syncPath()
        }
        .onChange(of: path) { newPath in
            handlePathChange(newPath)
        }
    }

    // MARK: - Roots

    private var hubRoot: some View {
        ZStack {
            PushModalBackground()
            VStack(spacing: 0) {
                PushCreamPageHeader(
                    title: CreatePostCopy.hubTitle,
                    subtitle: CreatePostCopy.hubSubtitle
                ) {
                    closeButton
                }
                .padding(.horizontal, CreatePostLayout.horizontalPadding(layout))
                .padding(.top, CreatePostLayout.navTopPadding)
                .padding(.bottom, CreatePostLayout.hubHeaderToSegmentSpacing(layout))

                CreatePostHubView(viewModel: viewModel)
            }
        }
    }

    private var selectFriendsRoot: some View {
        ZStack {
            PushModalBackground()
            VStack(spacing: 0) {
                secondaryNavBar
                    .padding(.horizontal, CreatePostLayout.horizontalPadding(layout))
                    .padding(.top, CreatePostLayout.navTopPadding)
                    .padding(.bottom, CreatePostLayout.navBottomPadding)

                CreatePostSelectFriendsView(viewModel: viewModel) {
                    viewModel.continueFromFriends()
                }
            }
        }
    }

    private var composeRoot: some View {
        ZStack {
            PushModalBackground()
            VStack(spacing: 0) {
                secondaryNavBar
                    .padding(.horizontal, CreatePostLayout.horizontalPadding(layout))
                    .padding(.top, CreatePostLayout.navTopPadding)
                    .padding(.bottom, CreatePostLayout.navBottomPadding)

                CreatePostComposeView(viewModel: viewModel) {
                    dismiss()
                }
            }
        }
    }

    private var secondaryNavBar: some View {
        HStack {
            if viewModel.phase != .success {
                backButton
            }
            Spacer(minLength: 0)
            closeButton
        }
    }

    private var backButton: some View {
        Button {
            popBack()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: CreatePostLayout.backIconSize, weight: .bold))
                Text("Back")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(PushControlColors.activeForeground)
            .padding(.horizontal, CreatePostLayout.backHorizontalPadding)
            .frame(height: CreatePostLayout.closeButtonSize)
            .pushControlGlass(cornerRadius: CreatePostLayout.closeButtonSize / 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CreatePostCopy.backAccessibility)
        .disabled(viewModel.phase == .submitting)
        .opacity(viewModel.phase == .submitting ? PushOpacityTokens.disabledControl : 1)
    }

    private var closeButton: some View {
        PushCircleIconButton(
            systemImageName: "xmark",
            accessibilityLabel: CreatePostCopy.closeAccessibility
        ) {
            dismiss()
        }
        .opacity(viewModel.phase == .submitting ? PushOpacityTokens.disabledControl : 1)
        .disabled(viewModel.phase == .submitting)
    }

    // MARK: - Path sync

    private static func desiredPath(for viewModel: CreatePostViewModel) -> [CreatePostRoute] {
        switch viewModel.screen {
        case .hub:
            return []
        case .selectFriends:
            if viewModel.isEditingPeopleFromCompose {
                // Push picker above compose so Back returns to the draft.
                if viewModel.usesFriendSelection {
                    return [.selectFriends, .compose, .selectFriends]
                }
                return [.compose, .selectFriends]
            }
            return [.selectFriends]
        case .compose:
            if viewModel.usesFriendSelection {
                return [.selectFriends, .compose]
            }
            return [.compose]
        }
    }

    private func syncPath() {
        let desired = Self.desiredPath(for: viewModel)
        if path != desired {
            path = desired
        }
    }

    private func handlePathChange(_ newPath: [CreatePostRoute]) {
        // Interactive pop / programmatic pop — mirror into the view model.
        if newPath.isEmpty {
            if viewModel.screen != .hub {
                viewModel.goBackToHub()
            }
            return
        }

        // Popped friend editor back onto compose (edit-from-compose).
        if viewModel.screen == .selectFriends, viewModel.isEditingPeopleFromCompose {
            let composePaths: Set<[CreatePostRoute]> = [
                [.compose],
                [.selectFriends, .compose],
            ]
            if composePaths.contains(newPath) {
                viewModel.cancelFriendEditor()
                return
            }
        }

        // Scratch compose Back → initial friend step.
        if newPath == [.selectFriends], viewModel.screen == .compose {
            viewModel.goBackToSelectFriends()
            return
        }
    }

    private func popBack() {
        switch viewModel.screen {
        case .selectFriends:
            viewModel.goBackFromFriendPicker()
        case .compose where viewModel.usesFriendSelection:
            viewModel.goBackToSelectFriends()
        case .compose:
            viewModel.goBackToHub()
        case .hub:
            break
        }
    }
}

#if DEBUG
struct CreatePostFlowView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            CreatePostFlowView(viewModel: fixtureViewModel())
        }

        PushPreviewMatrix {
            CreatePostFlowView(viewModel: seededComposeViewModel())
        }

        PushPreviewMatrix {
            CreatePostFlowView(viewModel: scratchFriendsViewModel())
        }
    }

    /// Fixture seam — the app path always loads the hub from repositories.
    @MainActor
    private static func fixtureViewModel() -> CreatePostViewModel {
        CreatePostViewModel(
            existingMoments: CreatePostFixtures.existingMoments,
            pastPushes: CreatePostFixtures.pastPushes,
            timing: .immediate
        )
    }

    @MainActor
    private static func seededComposeViewModel() -> CreatePostViewModel {
        let viewModel = fixtureViewModel()
        viewModel.selectChooserItem(id: CreatePostFixtures.existingMoments[0].id)
        return viewModel
    }

    @MainActor
    private static func scratchFriendsViewModel() -> CreatePostViewModel {
        let viewModel = fixtureViewModel()
        viewModel.startFromScratch()
        return viewModel
    }
}
#endif
