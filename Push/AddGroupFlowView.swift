//
//  AddGroupFlowView.swift
//  Push
//
//  3-step full-screen Add Group flow. Copies StartPushFlowView's chrome
//  mechanics (glass back/close buttons, slide transitions) but on the flat
//  cream Friends background with no numbered step indicator, per product
//  decision — this flow should read like part of Friends/Groups, not a
//  fourth Start Push step.
//

import SwiftUI

struct AddGroupFlowView: View {
    @StateObject private var viewModel: AddGroupViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout
    @State private var movingForward = true

    /// Called once creation succeeds, with the new group's id and the
    /// session-only photo (if any) so the caller can register it before
    /// opening the group's detail view.
    let onCreated: (FriendGroup.ID, UIImage?) -> Void

    init(container: AppDataContainer? = nil, onCreated: @escaping (FriendGroup.ID, UIImage?) -> Void) {
        _viewModel = StateObject(wrappedValue: AddGroupViewModel(container: container))
        self.onCreated = onCreated
    }

    var body: some View {
        ZStack {
            FriendsBackground()
            VStack(spacing: 0) {
                navBar
                    .padding(.horizontal, StartPushLayout.horizontalPadding(layout))
                    .padding(.top, StartPushLayout.navTopPadding)
                    .padding(.bottom, StartPushLayout.navBottomPadding)

                header
                    .padding(.horizontal, StartPushLayout.horizontalPadding(layout))
                    .padding(.bottom, AddGroupLayout.headerBottomPadding)

                Group {
                    switch viewModel.step {
                    case 1:
                        AddGroupStep1CreateView(viewModel: viewModel, onNext: advance)
                    case 2:
                        AddGroupStep2MembersView(viewModel: viewModel, onNext: advance)
                    default:
                        AddGroupStep3ReviewView(
                            viewModel: viewModel,
                            onEditPhoto: { goToStep(1) },
                            onEditMembers: { goToStep(2) },
                            onSubmit: submitAndFinish,
                            onRetryPhoto: retryPhotoAndFinish,
                            onContinueWithoutPhoto: continueWithoutPhoto
                        )
                    }
                }
                .id(viewModel.step)
                .transition(.asymmetric(
                    insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity)
                ))
            }
            .animation(.spring(response: 0.30, dampingFraction: 0.84), value: viewModel.step)
        }
    }

    private var header: some View {
        Text(stepTitle)
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stepTitle: String {
        switch viewModel.step {
        case 1: return "Create a group"
        case 2: return "Add members"
        default: return "Review"
        }
    }

    private var navBar: some View {
        HStack {
            if viewModel.step > 1 {
                backButton
            }
            Spacer(minLength: 0)
            closeButton
        }
    }

    private var backButton: some View {
        Button(action: goBack) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: StartPushLayout.backIconSize, weight: .bold))
                Text("Back")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(PushControlColors.activeForeground)
            .padding(.horizontal, StartPushLayout.backHorizontalPadding)
            .frame(height: StartPushLayout.closeButtonSize)
            .pushGlassBackground(cornerRadius: StartPushLayout.closeButtonSize / 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: StartPushLayout.closeIconSize, weight: .bold))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(width: StartPushLayout.closeButtonSize, height: StartPushLayout.closeButtonSize)
                .pushGlassBackground(cornerRadius: StartPushLayout.closeButtonSize / 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private func advance() {
        movingForward = true
        viewModel.advance()
    }

    private func goBack() {
        movingForward = false
        viewModel.goBack()
    }

    private func goToStep(_ step: Int) {
        movingForward = step > viewModel.step
        viewModel.goToStep(step)
    }

    private func submitAndFinish() async {
        guard let groupID = await viewModel.submit() else { return }
        // Photo failure: stay on review so the user can Retry or continue without.
        if viewModel.actionError != nil { return }
        onCreated(groupID, viewModel.pickedImage)
        dismiss()
    }

    private func retryPhotoAndFinish() async {
        let success = await viewModel.retryPhotoUpload()
        guard success, let groupID = viewModel.lastCreatedGroupID else { return }
        onCreated(groupID, viewModel.pickedImage)
        dismiss()
    }

    private func continueWithoutPhoto() {
        guard let groupID = viewModel.continueWithoutPhoto() else { return }
        onCreated(groupID, nil)
        dismiss()
    }
}

private enum AddGroupLayout {
    static let headerBottomPadding: CGFloat = 6
}
