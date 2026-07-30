//
//  AddYoursComponents.swift
//  Push
//
//  Hero, empty picker, and thumb-strip pieces for Add Yours.
//  Card chrome matches Start Push form surfaces (soft white fill + walnut stroke).
//

import PhotosUI
import SwiftUI

// MARK: - Fitted media stage

/// Sizes the hero or empty card into the remaining vertical space so the
/// thumb strip and primary CTA stay on-screen without scrolling.
struct AddYoursMediaStage: View {
    @Environment(\.pushLayout) private var layout
    let item: AddYoursDraftItem?
    let isLoading: Bool
    let showsRemove: Bool
    /// When false, an empty stage is a static placeholder (existing-Moment edit
    /// never opens the library — Add Yours owns append).
    var showsPicker: Bool = true
    @Binding var pickerSelection: [PhotosPickerItem]
    let maxSelection: Int
    let onRemove: () -> Void

    var body: some View {
        GeometryReader { geo in
            let size = stageSize(in: geo.size, hasItem: item != nil)
            Group {
                if let item {
                    AddYoursHeroPreview(
                        item: item,
                        size: size,
                        cornerRadius: AddYoursLayout.cardCornerRadius(layout),
                        showsRemove: showsRemove,
                        onRemove: onRemove
                    )
                } else if showsPicker {
                    AddYoursEmptyPicker(
                        isLoading: isLoading,
                        selection: $pickerSelection,
                        maxSelection: maxSelection,
                        size: size,
                        cornerRadius: AddYoursLayout.cardCornerRadius(layout)
                    )
                } else {
                    // Edit path with no remaining media — empty placeholder only.
                    RoundedRectangle(
                        cornerRadius: AddYoursLayout.cardCornerRadius(layout),
                        style: .continuous
                    )
                    .fill(PushCreamTokens.solidCard)
                    .frame(width: size.width, height: size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Empty state is a compact form card; selected media uses portrait fit-to-stage.
    private func stageSize(in bounds: CGSize, hasItem: Bool) -> CGSize {
        guard hasItem else {
            let height = min(
                max(AddYoursLayout.emptyMinHeight, bounds.height * 0.42),
                min(AddYoursLayout.emptyMaxHeight, bounds.height)
            )
            return CGSize(width: bounds.width, height: max(0, height))
        }
        return AddYoursLayout.fittedHeroSize(in: bounds)
    }
}

// MARK: - Hero

struct AddYoursHeroPreview: View {
    let item: AddYoursDraftItem
    let size: CGSize
    let cornerRadius: CGFloat
    let showsRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            media
                .frame(width: size.width, height: size.height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            PushColorPalette.Accent.walnut.opacity(AddYoursColor.cardStrokeOpacity),
                            lineWidth: AddYoursLayout.heroStrokeWidth
                        )
                }
                .overlay(alignment: .bottomLeading) {
                    if item.kind == .video {
                        videoBadge
                            .padding(AddYoursLayout.videoBadgeInset)
                    }
                }

            if showsRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: AddYoursLayout.removeIconSize, weight: .bold))
                        .foregroundStyle(PushControlColors.activeForeground)
                        .frame(
                            width: AddYoursLayout.removeControlSize,
                            height: AddYoursLayout.removeControlSize
                        )
                        // Opaque cream — glass would sample dark photos and go dark.
                        .background(Circle().fill(PushCreamTokens.solidCard))
                        .overlay {
                            Circle().stroke(
                                PushColorPalette.Accent.walnut.opacity(
                                    PushCreamTokens.solidCardStrokeOpacity
                                ),
                                lineWidth: PushCreamTokens.solidCardStrokeWidth
                            )
                        }
                }
                .buttonStyle(.plain)
                .padding(AddYoursLayout.removeInset)
                .accessibilityLabel(AddYoursCopy.removeAccessibility)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private var media: some View {
        if let image = item.previewImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
        } else {
            AddYoursVideoPlaceholder()
                .frame(width: size.width, height: size.height)
        }
    }

    private var videoBadge: some View {
        Image(systemName: "play.fill")
            .font(.system(size: AddYoursLayout.videoBadgeIconSize, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(
                width: AddYoursLayout.videoBadgeSize,
                height: AddYoursLayout.videoBadgeSize
            )
            .background(
                Circle().fill(Color.black.opacity(AddYoursLayout.videoBadgeFillOpacity))
            )
            .accessibilityLabel(AddYoursCopy.videoBadgeAccessibility)
    }
}

// MARK: - Empty picker

struct AddYoursEmptyPicker: View {
    let isLoading: Bool
    @Binding var selection: [PhotosPickerItem]
    let maxSelection: Int
    let size: CGSize
    let cornerRadius: CGFloat

    var body: some View {
        PhotosPicker(
            selection: $selection,
            maxSelectionCount: max(1, maxSelection),
            matching: .any(of: [.images, .videos])
        ) {
            VStack(spacing: AddYoursLayout.emptyStackSpacing) {
                ZStack {
                    Circle()
                        .fill(PushControlColors.activeFill)
                        .frame(
                            width: AddYoursLayout.emptyIconCircle,
                            height: AddYoursLayout.emptyIconCircle
                        )
                    if isLoading {
                        ProgressView()
                            .tint(PushControlColors.activeForeground)
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: AddYoursLayout.emptyIconSize, weight: .semibold))
                            .foregroundStyle(PushControlColors.activeForeground)
                    }
                }

                VStack(spacing: AddYoursLayout.emptyTextSpacing) {
                    Text(AddYoursCopy.emptyPrompt)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(PushControlColors.textEspresso)
                    Text(AddYoursCopy.emptyHint)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PushControlColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: size.width, height: size.height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AddYoursColor.cardFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        PushColorPalette.Accent.walnut.opacity(AddYoursColor.cardStrokeOpacity),
                        lineWidth: AddYoursLayout.heroStrokeWidth
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading || maxSelection <= 0)
        .accessibilityLabel("\(AddYoursCopy.emptyPrompt). \(AddYoursCopy.emptyHint)")
    }
}

// MARK: - Thumbs

struct AddYoursThumbStrip: View {
    let items: [AddYoursDraftItem]
    let focusedIndex: Int
    let canAddMore: Bool
    let remainingSlots: Int
    @Binding var pickerSelection: [PhotosPickerItem]
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: StartPushLayout.sectionLabelSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(AddYoursCopy.selectedSection)
                    .pushSectionLabelStyle()
                Spacer(minLength: 8)
                Text(
                    AddYoursCopy.selectedCountLabel(
                        count: items.count,
                        max: AddYoursLayout.maxSelectionCount
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(PushControlColors.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AddYoursLayout.thumbSpacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        AddYoursThumbCell(
                            item: item,
                            isSelected: index == focusedIndex
                        ) {
                            onSelect(index)
                        }
                    }

                    if canAddMore {
                        AddYoursAddThumbPicker(
                            selection: $pickerSelection,
                            maxSelection: remainingSlots
                        )
                    }
                }
                .padding(.vertical, AddYoursLayout.thumbStripVerticalPadding)
            }
        }
    }
}

struct AddYoursThumbCell: View {
    let item: AddYoursDraftItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                thumbMedia
                if item.kind == .video {
                    Image(systemName: "play.fill")
                        .font(.system(size: AddYoursLayout.thumbPlayIconSize, weight: .bold))
                        .foregroundStyle(Color.white)
                        .shadow(
                            color: .black.opacity(AddYoursLayout.thumbPlayShadowOpacity),
                            radius: AddYoursLayout.thumbPlayShadowRadius,
                            y: AddYoursLayout.thumbPlayShadowY
                        )
                }
            }
            .frame(width: AddYoursLayout.thumbSize, height: AddYoursLayout.thumbSize)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AddYoursLayout.thumbCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: AddYoursLayout.thumbCornerRadius,
                    style: .continuous
                )
                .stroke(
                    isSelected
                        ? PushControlColors.activeFill
                        : PushColorPalette.Accent.walnut.opacity(AddYoursColor.thumbIdleStrokeOpacity),
                    lineWidth: isSelected
                        ? AddYoursLayout.thumbSelectedStrokeWidth
                        : AddYoursLayout.thumbIdleStrokeWidth
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.kind == .video ? "Video" : "Photo")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var thumbMedia: some View {
        if let image = item.previewImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: AddYoursLayout.thumbSize, height: AddYoursLayout.thumbSize)
        } else {
            AddYoursVideoPlaceholder()
                .frame(width: AddYoursLayout.thumbSize, height: AddYoursLayout.thumbSize)
        }
    }
}

struct AddYoursAddThumbPicker: View {
    @Binding var selection: [PhotosPickerItem]
    let maxSelection: Int

    var body: some View {
        PhotosPicker(
            selection: $selection,
            maxSelectionCount: max(1, maxSelection),
            matching: .any(of: [.images, .videos])
        ) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: AddYoursLayout.thumbCornerRadius,
                    style: .continuous
                )
                .fill(AddYoursColor.cardFill)
                Image(systemName: "plus")
                    .font(.system(size: AddYoursLayout.addThumbIconSize, weight: .bold))
                    .foregroundStyle(PushControlColors.activeForeground)
            }
            .frame(width: AddYoursLayout.thumbSize, height: AddYoursLayout.thumbSize)
            .overlay {
                RoundedRectangle(
                    cornerRadius: AddYoursLayout.thumbCornerRadius,
                    style: .continuous
                )
                .stroke(
                    PushColorPalette.Accent.walnut.opacity(AddYoursColor.cardStrokeOpacity),
                    lineWidth: AddYoursLayout.thumbIdleStrokeWidth
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AddYoursCopy.addMoreAccessibility)
    }
}

struct AddYoursVideoPlaceholder: View {
    var body: some View {
        LinearGradient(
            colors: [
                AddYoursColor.videoPlaceholderTop,
                AddYoursColor.videoPlaceholderBottom,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "video.fill")
                .font(.system(size: AddYoursLayout.videoPlaceholderIconSize, weight: .semibold))
                .foregroundStyle(Color.white.opacity(AddYoursLayout.videoPlaceholderIconOpacity))
        }
    }
}
