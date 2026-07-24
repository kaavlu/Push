//
//  StartPushFlowView.swift
//  Push
//
//  Created by Manav Khanvilkar on 7/1/26.
//

import SwiftUI

struct StartPushFlowView: View {
    @StateObject private var viewModel: StartPushViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout
    @State private var movingForward = true
    @State private var isDeleteConfirmationPresented = false
    @State private var isAddFriendPresented = false

    @MainActor
    init(context: StartPushLaunchContext? = nil) {
        _viewModel = StateObject(wrappedValue: StartPushViewModel(context: context))
    }

    var body: some View {
        ZStack {
            PushModalBackground()
            VStack(spacing: 0) {
                navBar
                    .padding(.horizontal, StartPushLayout.horizontalPadding(layout))
                    .padding(.top, StartPushLayout.navTopPadding)
                    .padding(.bottom, StartPushLayout.navBottomPadding)

                StartPushStepIndicator(currentStep: viewModel.step)
                    .padding(.bottom, StartPushLayout.stepIndicatorBottomPadding)

                Group {
                    switch viewModel.step {
                    case 1:
                        StartPushStep1View(
                            viewModel: viewModel,
                            onNext: advance,
                            onAddFriends: { isAddFriendPresented = true }
                        )
                    case 2:
                        StartPushStep2View(viewModel: viewModel, onNext: advance)
                    case 3:
                        StartPushStep3View(viewModel: viewModel, onNext: submitAndAdvance)
                    default:
                        StartPushStep4View(
                            viewModel: viewModel,
                            onViewResponses: { dismiss() },
                            onEdit: goBack
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
        .fullScreenCover(isPresented: $isAddFriendPresented, onDismiss: {
            Task { await viewModel.load() }
        }) {
            AddFriendsView()
        }
        .pushConfirmation(
            isPresented: $isDeleteConfirmationPresented,
            title: "Delete this push?",
            confirmTitle: "Delete push",
            cancelTitle: "Keep push",
            onConfirm: { deleteAndDismiss() }
        )
    }

    private var navBar: some View {
        HStack {
            if viewModel.step > 1 && viewModel.step < 4 {
                backButton
            }
            Spacer(minLength: 0)
            if viewModel.canDeletePush {
                trashButton
                    .padding(.trailing, StartPushLayout.trashCloseSpacing)
            }
            closeButton
        }
    }

    private var trashButton: some View {
        PushCircleIconButton(
            systemImageName: "trash",
            accessibilityLabel: "Delete push",
            foreground: PushControlColors.destructive
        ) {
            isDeleteConfirmationPresented = true
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
        PushCircleIconButton(
            systemImageName: "xmark",
            accessibilityLabel: "Close"
        ) {
            dismiss()
        }
    }

    private func advance() {
        movingForward = true
        viewModel.advance()
    }

    private func submitAndAdvance() {
        movingForward = true
        Task {
            await viewModel.submit()
            viewModel.advance()
        }
    }

    private func goBack() {
        movingForward = false
        viewModel.goBack()
    }

    private func deleteAndDismiss() {
        Task {
            await viewModel.deletePush()
            dismiss()
        }
    }
}
