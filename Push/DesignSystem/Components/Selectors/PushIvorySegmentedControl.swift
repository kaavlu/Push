//
//  PushIvorySegmentedControl.swift
//  Push
//
//  DS-035 — ivory segmented mode switch for cream-page destinations.
//

import SwiftUI

struct PushIvorySegmentedItem: Identifiable, Equatable {
    let id: String
    let title: String
    var count: Int? = nil
}

enum PushIvorySegmentedMetrics {
    static let itemSpacing: CGFloat = 4
    static let padding: CGFloat = 4
    static let cornerRadius: CGFloat = 22
    static let itemCornerRadius: CGFloat = 18
    static let itemVerticalPadding: CGFloat = 9
    static let countSpacing: CGFloat = 6
    static let countHorizontalPadding: CGFloat = 7
    static let countVerticalPadding: CGFloat = 2
    static let containerShadowRadius: CGFloat = 10
    static let containerShadowYOffset: CGFloat = 3
    static let selectedShadowRadius: CGFloat = 8
    static let selectedShadowYOffset: CGFloat = 3
    static let animationResponse = 0.28
    static let animationDamping = 0.86
    static let selectionNamespaceID = "pushIvorySegmentSelection"
}

/// Champagne-track segmented control with optional count capsules.
struct PushIvorySegmentedControl: View {
    let items: [PushIvorySegmentedItem]
    @Binding var selectedID: String
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: PushIvorySegmentedMetrics.itemSpacing) {
            ForEach(items) { item in
                segment(item)
            }
        }
        .padding(PushIvorySegmentedMetrics.padding)
        .background(
            RoundedRectangle(cornerRadius: PushIvorySegmentedMetrics.cornerRadius, style: .continuous)
                .fill(FriendsColor.switchTrack)
                .shadow(
                    color: FriendsColor.switchTrackShadow.opacity(FriendsColor.switchContainerShadowOpacity),
                    radius: PushIvorySegmentedMetrics.containerShadowRadius,
                    y: PushIvorySegmentedMetrics.containerShadowYOffset
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: PushIvorySegmentedMetrics.cornerRadius, style: .continuous)
                .stroke(
                    FriendsColor.switchTrackHighlight.opacity(FriendsColor.switchContainerHighlightOpacity),
                    lineWidth: 0.8
                )
        }
        .overlay(alignment: .bottom) {
            RoundedRectangle(cornerRadius: PushIvorySegmentedMetrics.cornerRadius, style: .continuous)
                .stroke(
                    FriendsColor.switchTrackShadow.opacity(FriendsColor.switchContainerInsetOpacity),
                    lineWidth: 1
                )
        }
    }

    private func segment(_ item: PushIvorySegmentedItem) -> some View {
        let isSelected = selectedID == item.id
        return Button {
            withAnimation(
                .spring(
                    response: PushIvorySegmentedMetrics.animationResponse,
                    dampingFraction: PushIvorySegmentedMetrics.animationDamping
                )
            ) {
                selectedID = item.id
            }
        } label: {
            HStack(spacing: PushIvorySegmentedMetrics.countSpacing) {
                Text(item.title)
                    .font(.subheadline.weight(isSelected ? .bold : .semibold))
                if let count = item.count {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FriendsColor.switchCountText.opacity(isSelected ? 0.95 : 0.62))
                        .padding(.horizontal, PushIvorySegmentedMetrics.countHorizontalPadding)
                        .padding(.vertical, PushIvorySegmentedMetrics.countVerticalPadding)
                        .background(
                            Capsule().fill(
                                isSelected
                                    ? FriendsColor.switchActiveCountFill
                                    : FriendsColor.switchInactiveCountFill.opacity(0.58)
                            )
                        )
                }
            }
            .foregroundStyle(isSelected ? FriendsColor.switchActiveText : FriendsColor.switchInactiveText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, PushIvorySegmentedMetrics.itemVerticalPadding)
            .background {
                if isSelected {
                    RoundedRectangle(
                        cornerRadius: PushIvorySegmentedMetrics.itemCornerRadius,
                        style: .continuous
                    )
                    .fill(FriendsColor.switchSelectedCream)
                    .shadow(
                        color: FriendsColor.switchSelectedShadow.opacity(
                            FriendsColor.switchSelectedShadowOpacity
                        ),
                        radius: PushIvorySegmentedMetrics.selectedShadowRadius,
                        y: PushIvorySegmentedMetrics.selectedShadowYOffset
                    )
                    .matchedGeometryEffect(
                        id: PushIvorySegmentedMetrics.selectionNamespaceID,
                        in: namespace
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.count.map(String.init) ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
