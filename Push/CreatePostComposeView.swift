//
//  CreatePostComposeView.swift
//  Push
//
//  Shared compose shell for past-Push prefill, from-scratch drafts, and
//  existing-Moment edit (S9). Reuses Add Yours media stage / thumb strip patterns.
//

import PhotosUI
import SwiftUI

struct CreatePostComposeView: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var viewModel: CreatePostViewModel
    let onShared: () -> Void

    var body: some View {
        Group {
            if viewModel.phase == .success {
                successContent
            } else if viewModel.isEditingExistingMoment, viewModel.isRepositoryBacked {
                // Repo path: load surfaces until MomentDetail is ready.
                editSurface
            } else {
                // Create paths + fixture/preview edit seam.
                composingContent
            }
        }
        .animation(PushMotion.contentCrossfade, value: viewModel.phase)
        .animation(PushMotion.contentCrossfade, value: viewModel.editContentPhase)
        .onChange(of: viewModel.shouldDismissAfterEdit) { shouldDismiss in
            guard shouldDismiss else { return }
            viewModel.acknowledgeEditDismissal()
            onShared()
        }
    }

    // MARK: - Edit load surfaces

    @ViewBuilder
    private var editSurface: some View {
        switch viewModel.editContentPhase {
        case .loading, .deferred:
            EmptySurfaceStateView.loading
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            EmptySurfaceStateView.failed(surface: CreatePostEditCopy.surfaceName) {
                Task { await viewModel.retryEditLoad() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty, .content:
            if viewModel.isEditSurfaceDenied {
                EmptySurfaceView(
                    title: CreatePostEditCopy.deniedTitle,
                    message: CreatePostEditCopy.deniedMessage,
                    systemImage: "lock.fill"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                composingContent
            }
        }
    }

    // MARK: - Composing

    /// Bottom CTA matches friend-picker “Done”: clear→white scrim so With rows
    /// scroll under the button instead of sitting above a solid cream slab.
    private var composingContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: CreatePostLayout.sectionSpacing(layout)) {
                StartPushHeader(
                    title: viewModel.composeTitle,
                    subtitle: viewModel.composeSubtitle
                )

                mediaBlock
                fieldsBlock
                peopleBlock
            }
            .padding(.horizontal, CreatePostLayout.horizontalPadding(layout))
            .padding(.bottom, CreatePostLayout.contentTopSpacing)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: CreatePostLayout.fieldStackSpacing) {
                // Recoverable publish / edit failure — the draft below stays intact.
                if let actionError = viewModel.actionError {
                    ActionErrorBanner(
                        message: actionError.message,
                        onRetry: { Task { await viewModel.retryPublish() } },
                        onDismiss: { viewModel.dismissActionError() }
                    )
                }
                if viewModel.showsPrimarySaveAction {
                    primaryActionBar
                }
            }
            .padding(.horizontal, CreatePostLayout.horizontalPadding(layout))
            .padding(.bottom, CreatePostLayout.bottomPadding(layout))
            .background(bottomBarBackground)
        }
    }

    private var primaryActionBar: some View {
        PushSolidSunbeamButton(
            title: viewModel.primaryButtonTitle,
            isEnabled: viewModel.canSubmit,
            isLoading: viewModel.isPrimaryLoading,
            action: {
                Task {
                    await viewModel.submit()
                    if viewModel.phase == .success, !viewModel.shouldDismissAfterEdit {
                        onShared()
                    }
                }
            }
        )
        .opacity(viewModel.phase == .submitting ? PushOpacityTokens.disabledControl : 1)
    }

    /// Same scrim as `CreatePostSelectFriendsView` bottom bar.
    private var bottomBarBackground: some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.92)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var mediaBlock: some View {
        VStack(alignment: .leading, spacing: CreatePostLayout.fieldStackSpacing) {
            AddYoursMediaStage(
                item: viewModel.focusedItem,
                isLoading: viewModel.isLoadingPicker,
                showsRemove: viewModel.canDeleteFocusedMedia,
                // Existing-Moment edit never picks new media (Add Yours owns append).
                showsPicker: !(viewModel.isEditingExistingMoment && viewModel.isRepositoryBacked),
                pickerSelection: $viewModel.pickerItems,
                maxSelection: max(viewModel.remainingSlots, 1),
                onRemove: { viewModel.removeFocusedItem() }
            )
            .frame(maxWidth: .infinity)
            .frame(height: composeMediaHeight)

            if !viewModel.items.isEmpty {
                CreatePostReorderableThumbStrip(
                    items: viewModel.items,
                    focusedIndex: viewModel.focusedIndex,
                    canAddMore: viewModel.canAddMoreOnCompose,
                    canReorder: viewModel.canReorderEditMedia,
                    remainingSlots: viewModel.remainingSlots,
                    pickerSelection: $viewModel.pickerItems,
                    onSelect: { viewModel.selectItem(at: $0) },
                    onMove: { from, to in
                        withAnimation(PushMotion.selection) {
                            viewModel.moveMedia(from: from, to: to)
                        }
                    }
                )
            }
        }
    }

    private var composeMediaHeight: CGFloat {
        CreatePostLayout.composeMediaStageHeight
    }

    private var fieldsBlock: some View {
        VStack(spacing: CreatePostLayout.fieldStackSpacing) {
            CreatePostTextField(
                text: $viewModel.titleText,
                placeholder: CreatePostCopy.titlePlaceholder,
                isEnabled: viewModel.canEditMetadataFields
            )
            CreatePostTextField(
                text: $viewModel.locationText,
                placeholder: CreatePostCopy.locationPlaceholder,
                isEnabled: viewModel.canEditMetadataFields
            )
        }
    }

    /// Tagged people — header row includes Edit to open the friend picker.
    private var peopleBlock: some View {
        VStack(alignment: .leading, spacing: CreatePostLayout.sectionLabelSpacing) {
            peopleSectionHeader

            if viewModel.memberPersonRows.isEmpty {
                Text(CreatePostCopy.peopleEmptyMessage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PushControlColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: FriendsLayout.listSpacing) {
                    ForEach(viewModel.memberPersonRows) { row in
                        PushPersonRow(
                            row: row,
                            showsGroupLabel: false,
                            showsStatusDetail: false,
                            usesAvailabilityAppearance: false,
                            customTrailing: AnyView(EmptyView())
                        )
                    }
                }
            }
        }
    }

    private var peopleSectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(CreatePostCopy.peopleSection)
                .pushSectionLabelStyle()
            Spacer(minLength: 0)
            if viewModel.canEditPeople {
                Button {
                    viewModel.openFriendEditor()
                } label: {
                    // Same type as WITH; SF chevron matches Back (chevron.left) weight/size.
                    HStack(spacing: 4) {
                        Text(CreatePostCopy.peopleEditAction)
                            .pushSectionLabelStyle()
                        Image(systemName: "chevron.right")
                            .font(.system(size: CreatePostLayout.backIconSize, weight: .bold))
                            .foregroundStyle(PushControlColors.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(CreatePostCopy.peopleEditAction)
                .accessibilityHint("Edit who is tagged on this moment")
            }
        }
    }

    // MARK: - Success

    private var successContent: some View {
        let title = viewModel.isEditingExistingMoment
            ? CreatePostEditCopy.editSuccessTitle
            : CreatePostCopy.successTitle
        let message = viewModel.isEditingExistingMoment
            ? CreatePostEditCopy.editSuccessMessage
            : CreatePostCopy.successMessage
        return VStack(spacing: CreatePostLayout.successStackSpacing) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(PushColorPalette.Accent.sunbeam)
                    .frame(
                        width: CreatePostLayout.successIconFrame,
                        height: CreatePostLayout.successIconFrame
                    )
                Image(systemName: "checkmark")
                    .font(.system(size: CreatePostLayout.successIconSize, weight: .bold))
                    .foregroundStyle(PushControlColors.activeForeground)
            }
            .shadow(
                color: PushColorPalette.Accent.walnut.opacity(CreatePostLayout.successShadowOpacity),
                radius: CreatePostLayout.successShadowRadius,
                y: CreatePostLayout.successShadowY
            )

            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PushControlColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CreatePostLayout.horizontalPadding(layout))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - Text field

private struct CreatePostTextField: View {
    @Environment(\.pushLayout) private var layout
    @Binding var text: String
    let placeholder: String
    var isEnabled: Bool = true

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PushControlColors.textEspresso)
            .tint(PushControlColors.activeForeground)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : PushOpacityTokens.disabledControl)
            .padding(.horizontal, CreatePostLayout.fieldHorizontalPadding)
            .frame(height: CreatePostLayout.fieldHeight)
            .background {
                RoundedRectangle(
                    cornerRadius: CreatePostLayout.fieldCornerRadius,
                    style: .continuous
                )
                .fill(Color.white.opacity(CreatePostColor.fieldFill))
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: CreatePostLayout.fieldCornerRadius,
                    style: .continuous
                )
                .stroke(
                    PushColorPalette.Accent.walnut.opacity(CreatePostColor.cardStrokeOpacity),
                    lineWidth: 1
                )
            }
    }
}
