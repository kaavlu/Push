//
//  CreatePostComposeView.swift
//  Push
//
//  Shared compose shell for past-Push prefill and from-scratch drafts.
//  Reuses Add Yours media stage / thumb strip patterns.
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
            } else {
                composingContent
            }
        }
        .animation(PushMotion.contentCrossfade, value: viewModel.phase)
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
            primaryActionBar
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
                    if viewModel.phase == .success {
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
                showsRemove: viewModel.phase == .composing && viewModel.focusedItem != nil,
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
                    canAddMore: viewModel.canAddMore,
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
                placeholder: CreatePostCopy.titlePlaceholder
            )
            CreatePostTextField(
                text: $viewModel.locationText,
                placeholder: CreatePostCopy.locationPlaceholder
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
        VStack(spacing: CreatePostLayout.successStackSpacing) {
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

            Text(CreatePostCopy.successTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text(CreatePostCopy.successMessage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PushControlColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CreatePostLayout.horizontalPadding(layout))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(CreatePostCopy.successTitle). \(CreatePostCopy.successMessage)")
    }
}

// MARK: - Text field

private struct CreatePostTextField: View {
    @Environment(\.pushLayout) private var layout
    @Binding var text: String
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(PushControlColors.textEspresso)
            .tint(PushControlColors.activeForeground)
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
