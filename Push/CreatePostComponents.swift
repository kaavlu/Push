//
//  CreatePostComponents.swift
//  Push
//
//  Create-post adapters over design-system chooser rows + media strip.
//  Row chrome lives in PushMomentChooserRow / PushContributionChip (DS-091).
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Chooser row adapter

struct CreatePostChooserRow: View {
    let item: CreatePostHistoryItem

    var body: some View {
        switch item.style {
        case .existingMoment:
            existingMomentRow
        case .pastPush:
            pastPushRow
        }
    }

    private var existingMomentRow: some View {
        let contribution = item.contributionState ?? .openForAdds
        return PushMomentChooserRow(
            title: item.title,
            metaLine: item.metaLine,
            contributors: item.contributors.map(\.asChooserPerson),
            mediaCountLabel: item.mediaCountLabel,
            mediaAccessibilityLabel: item.mediaAccessibilityLabel,
            contributionTitle: contribution.chipTitle,
            contributionKind: contribution.chipKind
        ) {
            CreatePostRowLeadingThumb(item: item)
        }
    }

    private var pastPushRow: some View {
        PushPastPushChooserRow(
            title: item.title,
            metaLine: item.metaLine,
            participants: item.participants.map(\.asChooserPerson)
        )
    }
}

// MARK: - Leading media thumb (FeedMediaItem → DS frame)

struct CreatePostRowLeadingThumb: View {
    @Environment(\.pushLayout) private var layout
    let item: CreatePostHistoryItem

    private var size: CGFloat { PushMomentChooserMetrics.rowThumbSize(layout) }

    var body: some View {
        PushChooserThumbFrame(size: size) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let media = item.carouselThumbnailMedia {
            CreatePostMediaThumb(item: media)
        } else if let person = item.contributors.first ?? item.participants.first {
            PushPersonAvatar(
                imageAssetName: person.imageAssetPath,
                fallbackInitials: person.initials,
                fallbackStyle: .dark
            )
        } else {
            Image(systemName: "photo")
                .font(.system(
                    size: PushMomentChooserMetrics.rowThumbPlaceholderIconSize,
                    weight: .semibold
                ))
                .foregroundStyle(PushControlColors.textTertiary)
        }
    }
}

// MARK: - Media thumb

struct CreatePostMediaThumb: View {
    let item: FeedMediaItem

    var body: some View {
        Group {
            switch item.source {
            case .assetPath(let path):
                if let image = AvatarImageLoader.localImage(for: path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    solidPlaceholder
                }
            case .solidColor(let swatch):
                Image(uiImage: FeedMediaImageFactory.image(for: swatch))
                    .resizable()
                    .scaledToFill()
            case .loading, .missing:
                solidPlaceholder
            }
        }
    }

    private var solidPlaceholder: some View {
        LinearGradient(
            colors: [
                CreatePostColor.mediaPlaceholderTop,
                CreatePostColor.mediaPlaceholderBottom,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Reorderable media strip

/// Horizontal media strip with long-press drag reorder. Index 0 is the cover.
struct CreatePostReorderableThumbStrip: View {
    let items: [AddYoursDraftItem]
    let focusedIndex: Int
    let canAddMore: Bool
    /// When false, drag/drop reorder is disabled (capability-shaped edit).
    var canReorder: Bool = true
    let remainingSlots: Int
    @Binding var pickerSelection: [PhotosPickerItem]
    let onSelect: (Int) -> Void
    let onMove: (Int, Int) -> Void

    @State private var draggingID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: StartPushLayout.sectionLabelSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(CreatePostCopy.mediaSelectedSection)
                    .pushSectionLabelStyle()
                Spacer(minLength: 8)
                Text(
                    CreatePostCopy.selectedCountLabel(
                        count: items.count,
                        max: CreatePostLayout.maxSelectionCount
                    )
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(PushControlColors.textTertiary)
            }

            if canReorder {
                Text(CreatePostCopy.mediaReorderHint)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(PushControlColors.textTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AddYoursLayout.thumbSpacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        CreatePostReorderableThumbCell(
                            item: item,
                            isSelected: index == focusedIndex,
                            isCover: index == 0 && items.count > 1,
                            isDragging: draggingID == item.id
                        ) {
                            onSelect(index)
                        }
                        .modifier(
                            CreatePostThumbReorderModifier(
                                item: item,
                                items: items,
                                canReorder: canReorder,
                                draggingID: $draggingID,
                                onMove: onMove
                            )
                        )
                    }

                    if canAddMore {
                        AddYoursAddThumbPicker(
                            selection: $pickerSelection,
                            maxSelection: remainingSlots
                        )
                    }
                }
                .padding(.vertical, AddYoursLayout.thumbStripVerticalPadding)
                .animation(PushMotion.selection, value: items.map(\.id))
            }
        }
        .accessibilityHint(canReorder ? CreatePostCopy.mediaReorderHint : "")
    }
}

/// Applies drag/drop only when reorder is allowed — keeps the strip readable.
private struct CreatePostThumbReorderModifier: ViewModifier {
    let item: AddYoursDraftItem
    let items: [AddYoursDraftItem]
    let canReorder: Bool
    @Binding var draggingID: UUID?
    let onMove: (Int, Int) -> Void

    func body(content: Content) -> some View {
        if canReorder {
            content
                .onDrag {
                    draggingID = item.id
                    return NSItemProvider(object: item.id.uuidString as NSString)
                } preview: {
                    CreatePostThumbDragPreview(item: item)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: CreatePostThumbDropDelegate(
                        targetID: item.id,
                        items: items,
                        draggingID: $draggingID,
                        onMove: onMove
                    )
                )
        } else {
            content
        }
    }
}

private struct CreatePostReorderableThumbCell: View {
    let item: AddYoursDraftItem
    let isSelected: Bool
    let isCover: Bool
    let isDragging: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
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

                if isCover {
                    Text(CreatePostCopy.mediaCoverBadge)
                        .font(.system(size: CreatePostLayout.coverBadgeFontSize, weight: .bold))
                        .foregroundStyle(PushControlColors.activeForeground)
                        .padding(.horizontal, CreatePostLayout.coverBadgeHorizontalPadding)
                        .padding(.vertical, CreatePostLayout.coverBadgeVerticalPadding)
                        .background(
                            Capsule().fill(PushColorPalette.Accent.sunbeam)
                        )
                        .padding(CreatePostLayout.coverBadgeInset)
                }
            }
            .scaleEffect(isDragging ? CreatePostLayout.thumbDragScale : 1)
            .shadow(
                color: PushColorPalette.Accent.walnut.opacity(
                    isDragging ? CreatePostLayout.thumbDragShadowOpacity : 0
                ),
                radius: isDragging ? CreatePostLayout.thumbDragShadowRadius : 0,
                y: isDragging ? CreatePostLayout.thumbDragShadowY : 0
            )
            .animation(PushMotion.selectionSnappy, value: isDragging)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.kind == .video ? "Video" : "Photo")
        .accessibilityValue(isCover ? CreatePostCopy.mediaCoverBadge : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(CreatePostCopy.mediaReorderHint)
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

private struct CreatePostThumbDragPreview: View {
    let item: AddYoursDraftItem

    var body: some View {
        Group {
            if let image = item.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                AddYoursVideoPlaceholder()
            }
        }
        .frame(width: AddYoursLayout.thumbSize, height: AddYoursLayout.thumbSize)
        .clipShape(
            RoundedRectangle(
                cornerRadius: AddYoursLayout.thumbCornerRadius,
                style: .continuous
            )
        )
        .shadow(
            color: PushColorPalette.Accent.walnut.opacity(CreatePostLayout.thumbDragShadowOpacity),
            radius: CreatePostLayout.thumbDragShadowRadius,
            y: CreatePostLayout.thumbDragShadowY
        )
    }
}

private struct CreatePostThumbDropDelegate: DropDelegate {
    let targetID: UUID
    let items: [AddYoursDraftItem]
    @Binding var draggingID: UUID?
    let onMove: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard
            let draggingID,
            draggingID != targetID,
            let from = items.firstIndex(where: { $0.id == draggingID }),
            let to = items.firstIndex(where: { $0.id == targetID })
        else { return }
        onMove(from, to)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropExited(info: DropInfo) {
        // Keep draggingID until performDrop / cancel.
    }
}

// MARK: - FeedMediaParticipant → chooser person

private extension FeedMediaParticipant {
    var asChooserPerson: PushChooserPerson {
        PushChooserPerson(
            id: id,
            displayName: displayName,
            initials: initials,
            imageAssetPath: imageAssetPath
        )
    }
}
