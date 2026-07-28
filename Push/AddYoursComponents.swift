//
//  AddYoursComponents.swift
//  Push
//
//  Hero, empty picker, and thumb-strip pieces for Add Yours.
//

import PhotosUI
import SwiftUI

// MARK: - Hero

struct AddYoursHeroPreview: View {
    let item: AddYoursDraftItem
    let showsRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            media
                .frame(maxWidth: .infinity)
                .aspectRatio(AddYoursLayout.heroAspectRatio, contentMode: .fit)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: AddYoursLayout.heroCornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: AddYoursLayout.heroCornerRadius,
                        style: .continuous
                    )
                    .stroke(
                        PushColorPalette.Accent.walnut.opacity(AddYoursLayout.heroStrokeOpacity),
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
                        .background(
                            Circle().fill(Color.white.opacity(AddYoursLayout.removeFillOpacity))
                        )
                        .overlay {
                            Circle()
                                .stroke(
                                    PushColorPalette.Accent.walnut.opacity(
                                        AddYoursLayout.removeStrokeOpacity
                                    ),
                                    lineWidth: AddYoursLayout.removeStrokeWidth
                                )
                        }
                }
                .buttonStyle(.plain)
                .padding(AddYoursLayout.removeInset)
                .accessibilityLabel(AddYoursCopy.removeAccessibility)
            }
        }
    }

    @ViewBuilder
    private var media: some View {
        if let image = item.previewImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            AddYoursVideoPlaceholder()
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

    var body: some View {
        PhotosPicker(
            selection: $selection,
            maxSelectionCount: max(1, maxSelection),
            matching: .any(of: [.images, .videos])
        ) {
            VStack(spacing: AddYoursLayout.emptyStackSpacing) {
                if isLoading {
                    ProgressView()
                        .tint(PushControlColors.activeForeground)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: AddYoursLayout.emptyIconSize, weight: .bold))
                        .foregroundStyle(PushControlColors.activeForeground)
                }
                Text(AddYoursCopy.emptyPrompt)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PushControlColors.textEspresso)
                Text(AddYoursCopy.emptyHint)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PushControlColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(AddYoursLayout.heroAspectRatio, contentMode: .fit)
            .background(
                RoundedRectangle(
                    cornerRadius: AddYoursLayout.heroCornerRadius,
                    style: .continuous
                )
                .fill(AddYoursColor.emptyFill)
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: AddYoursLayout.heroCornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    style: StrokeStyle(
                        lineWidth: AddYoursLayout.emptyDashStrokeWidth,
                        dash: [AddYoursLayout.emptyDashLength, AddYoursLayout.emptyDashPhase]
                    )
                )
                .foregroundStyle(
                    PushColorPalette.Accent.walnut.opacity(AddYoursLayout.emptyStrokeOpacity)
                )
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading || maxSelection <= 0)
        .accessibilityLabel("\(AddYoursCopy.emptyPrompt). \(AddYoursCopy.emptyHint)")
    }
}

// MARK: - Thumbs

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
        } else {
            AddYoursVideoPlaceholder()
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
                .fill(AddYoursColor.emptyFill)
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
                .strokeBorder(
                    style: StrokeStyle(
                        lineWidth: AddYoursLayout.addThumbStrokeWidth,
                        dash: AddYoursLayout.addThumbDash
                    )
                )
                .foregroundStyle(
                    PushColorPalette.Accent.walnut.opacity(AddYoursLayout.emptyStrokeOpacity)
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
