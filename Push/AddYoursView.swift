//
//  AddYoursView.swift
//  Push
//
//  Single-screen Add Yours contribution flow. Cream-page header (title + close
//  aligned like Feed/Pushes), form-card media stage, fixed primary CTA.
//  Thumb strip stays pinned above the button — no scroll to manage selection.
//
//  The album, the capacity, and whether the action is offered at all come from
//  the Moment the view model loads (S8) — never from the Feed card that opened it.
//

import PhotosUI
import SwiftUI

struct AddYoursView: View {
    @StateObject private var viewModel: AddYoursViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout

    @MainActor
    init(context: AddYoursContext, viewModel: AddYoursViewModel? = nil) {
        if let viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: AddYoursViewModel(context: context))
        }
    }

    var body: some View {
        ZStack {
            PushModalBackground()

            VStack(spacing: 0) {
                pageHeader
                    .padding(.horizontal, AddYoursLayout.horizontalPadding(layout))
                    .padding(.top, AddYoursLayout.navTopPadding)
                    .padding(.bottom, AddYoursLayout.navBottomPadding)

                if viewModel.phase == .success {
                    successContent
                } else {
                    loadedContent
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let actionError = viewModel.actionError {
                ActionErrorBanner(
                    message: actionError.message,
                    onRetry: { Task { await viewModel.retrySubmit() } },
                    onDismiss: { viewModel.dismissActionError() }
                )
                .padding(.horizontal, AddYoursLayout.horizontalPadding(layout))
                .padding(.bottom, AddYoursLayout.bottomPadding(layout))
            }
        }
        .animation(PushMotion.contentCrossfade, value: viewModel.phase)
    }

    // MARK: - Header (aligned with close, Pushes/Feed typography)

    private var pageHeader: some View {
        PushCreamPageHeader(
            title: AddYoursCopy.title,
            subtitle: viewModel.context.subtitle
        ) {
            PushCircleIconButton(
                systemImageName: "xmark",
                accessibilityLabel: "Close"
            ) {
                dismiss()
            }
            .opacity(viewModel.phase == .submitting ? PushOpacityTokens.disabledControl : 1)
            .disabled(viewModel.phase == .submitting)
        }
    }

    // MARK: - Load states (DS-070/071)

    @ViewBuilder
    private var loadedContent: some View {
        switch viewModel.contentPhase {
        case .loading, .deferred:
            EmptySurfaceStateView.loading
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            EmptySurfaceStateView.failed(surface: AddYoursCopy.surfaceName) {
                Task { await viewModel.load() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty, .content:
            if viewModel.isDenied {
                blockedState(
                    title: AddYoursCopy.deniedTitle,
                    message: AddYoursCopy.deniedMessage,
                    systemImage: "lock"
                )
            } else if viewModel.isFull {
                blockedState(
                    title: AddYoursCopy.fullTitle,
                    message: AddYoursCopy.fullMessage,
                    systemImage: "rectangle.stack"
                )
            } else {
                composingContent
            }
        }
    }

    private func blockedState(
        title: String,
        message: String,
        systemImage: String
    ) -> some View {
        EmptySurfaceView(title: title, message: message, systemImage: systemImage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, AddYoursLayout.horizontalPadding(layout))
    }

    // MARK: - Composing (fixed layout — no page scroll)

    private var composingContent: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AddYoursLayout.headerToStageSpacing) {
                AddYoursMediaStage(
                    item: viewModel.focusedItem,
                    isLoading: viewModel.isLoadingPicker,
                    showsRemove: viewModel.phase == .composing && viewModel.focusedItem != nil,
                    pickerSelection: $viewModel.pickerItems,
                    maxSelection: max(viewModel.remainingSlots, 1),
                    onRemove: { viewModel.removeFocusedItem() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !viewModel.items.isEmpty {
                    AddYoursThumbStrip(
                        items: viewModel.items,
                        focusedIndex: viewModel.focusedIndex,
                        canAddMore: viewModel.canAddMore,
                        remainingSlots: viewModel.remainingSlots,
                        pickerSelection: $viewModel.pickerItems,
                        onSelect: { viewModel.selectItem(at: $0) }
                    )
                }
            }
            .padding(.horizontal, AddYoursLayout.horizontalPadding(layout))
            .padding(.top, AddYoursLayout.contentTopSpacing)
            .padding(.bottom, AddYoursLayout.stripToButtonSpacing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            PushSolidSunbeamButton(
                title: viewModel.primaryButtonTitle,
                isEnabled: viewModel.canSubmit,
                isLoading: viewModel.isPrimaryLoading,
                action: {
                    Task {
                        await viewModel.submit()
                        if viewModel.phase == .success {
                            dismiss()
                        }
                    }
                }
            )
            .padding(.horizontal, AddYoursLayout.horizontalPadding(layout))
            .padding(.bottom, AddYoursLayout.bottomPadding(layout))
        }
    }

    // MARK: - Success

    private var successContent: some View {
        VStack(spacing: AddYoursLayout.successStackSpacing) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(PushColorPalette.Accent.sunbeam)
                    .frame(
                        width: AddYoursLayout.successIconFrame,
                        height: AddYoursLayout.successIconFrame
                    )
                Image(systemName: "checkmark")
                    .font(.system(size: AddYoursLayout.successIconSize, weight: .bold))
                    .foregroundStyle(PushControlColors.activeForeground)
            }
            .shadow(
                color: PushColorPalette.Accent.walnut.opacity(AddYoursLayout.successShadowOpacity),
                radius: AddYoursLayout.successShadowRadius,
                y: AddYoursLayout.successShadowY
            )

            Text(AddYoursCopy.successTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text(AddYoursCopy.successMessage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PushControlColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AddYoursLayout.horizontalPadding(layout))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(AddYoursCopy.successTitle). \(AddYoursCopy.successMessage)")
    }
}

#if DEBUG
struct AddYoursView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            AddYoursView(
                context: AddYoursFixtures.sampleContext,
                viewModel: previewViewModel()
            )
        }

        PushPreviewMatrix {
            AddYoursView(
                context: AddYoursFixtures.sampleContext,
                viewModel: previewViewModel(seeded: true)
            )
        }
    }

    /// Preview seam only — no repository, so nothing here can be published.
    @MainActor
    private static func previewViewModel(seeded: Bool = false) -> AddYoursViewModel {
        AddYoursViewModel(
            previewDetail: AddYoursFixtures.previewDetail,
            items: seeded ? AddYoursFixtures.sampleDraftItems() : [],
            timing: .immediate
        )
    }
}
#endif
