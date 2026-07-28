//
//  AddYoursView.swift
//  Push
//
//  Single-screen Add Yours contribution flow — modal gradient, hero preview,
//  thumb strip, multi PhotosPicker. Local state only (no uploads).
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
                navBar
                    .padding(.horizontal, AddYoursLayout.horizontalPadding(layout))
                    .padding(.top, AddYoursLayout.navTopPadding)
                    .padding(.bottom, AddYoursLayout.navBottomPadding)

                if viewModel.phase == .success {
                    successContent
                } else {
                    composingContent
                }
            }
        }
        .animation(PushMotion.contentCrossfade, value: viewModel.phase)
    }

    // MARK: - Nav

    private var navBar: some View {
        HStack {
            Spacer(minLength: 0)
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

    // MARK: - Composing

    private var composingContent: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AddYoursLayout.sectionSpacing(layout)) {
                    header
                    heroSection
                    if !viewModel.items.isEmpty {
                        thumbStrip
                    }
                }
                .padding(.horizontal, AddYoursLayout.horizontalPadding(layout))
                .padding(.top, AddYoursLayout.contentTopSpacing)
                .padding(.bottom, AddYoursLayout.contentTopSpacing)
            }

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

    private var header: some View {
        VStack(alignment: .leading, spacing: AddYoursLayout.headerSpacing) {
            Text(AddYoursCopy.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text(viewModel.context.subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PushControlColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var heroSection: some View {
        if let item = viewModel.focusedItem {
            AddYoursHeroPreview(
                item: item,
                showsRemove: viewModel.phase == .composing,
                onRemove: { viewModel.removeFocusedItem() }
            )
        } else {
            AddYoursEmptyPicker(
                isLoading: viewModel.isLoadingPicker,
                selection: $viewModel.pickerItems,
                maxSelection: viewModel.remainingSlots
            )
        }
    }

    private var thumbStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AddYoursLayout.thumbSpacing) {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    AddYoursThumbCell(
                        item: item,
                        isSelected: index == viewModel.focusedIndex
                    ) {
                        viewModel.selectItem(at: index)
                    }
                }

                if viewModel.canAddMore {
                    AddYoursAddThumbPicker(
                        selection: $viewModel.pickerItems,
                        maxSelection: viewModel.remainingSlots
                    )
                }
            }
            .padding(.vertical, AddYoursLayout.thumbStripVerticalPadding)
        }
        .padding(.top, AddYoursLayout.thumbStripTopPadding)
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
            AddYoursView(context: AddYoursFixtures.sampleContext)
        }

        PushPreviewMatrix {
            AddYoursView(
                context: AddYoursFixtures.sampleContext,
                viewModel: seededPreviewViewModel()
            )
        }
    }

    @MainActor
    private static func seededPreviewViewModel() -> AddYoursViewModel {
        let viewModel = AddYoursViewModel(
            context: AddYoursFixtures.sampleContext,
            timing: .immediate
        )
        viewModel.seed(with: AddYoursFixtures.sampleDraftItems())
        return viewModel
    }
}
#endif
