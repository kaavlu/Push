//
//  BottomNavigationBar.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI

struct BottomNavigationBar: View {
    @Environment(\.pushLayout) private var layout
    @Binding var selectedItem: BottomNavigationItem
    let action: (BottomNavigationItem) -> Void

    var body: some View {
        PushGlass(layout: layout) {
            HStack(spacing: BottomNavigationLayout.itemSpacing) {
                ForEach(BottomNavigationItem.allCases) { item in
                    Button {
                        action(item)
                    } label: {
                        if item.isPrimaryAction {
                            PrimaryNavigationButtonLabel(layout: layout, isSelected: selectedItem == item)
                        } else {
                            BottomNavigationButtonLabel(
                                layout: layout,
                                item: item,
                                isSelected: selectedItem == item && item.showsSelectionHighlight
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityValue(selectedItem == item ? "Selected" : "Not selected")
                }
            }
        }
    }
}

private struct BottomNavigationButtonLabel: View {
    let layout: PushAdaptiveLayout
    let item: BottomNavigationItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: BottomNavigationLayout.labelSpacing) {
            Image(systemName: item.systemImageName)
                .font(.system(size: BottomNavigationLayout.iconSize(layout), weight: .semibold))

            Text(item.title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(BottomNavigationLayout.minimumTextScale)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(isSelected ? PushControlColors.activeForeground : PushControlColors.inactiveForeground)
        .padding(.vertical, BottomNavigationLayout.itemVerticalPadding(layout))
        .padding(.horizontal, BottomNavigationLayout.itemHorizontalPadding)
        .background(selectionBackground)
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            Capsule()
                .fill(PushControlColors.activeFill)
        }
    }
}

private struct PrimaryNavigationButtonLabel: View {
    let layout: PushAdaptiveLayout
    let isSelected: Bool

    var body: some View {
        Image(systemName: BottomNavigationItem.create.systemImageName)
            .font(.system(size: BottomNavigationLayout.primaryIconSize(layout), weight: .bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(
                width: BottomNavigationLayout.primaryButtonSize(layout),
                height: BottomNavigationLayout.primaryButtonSize(layout)
            )
            .background(primaryBackground)
            .overlay {
                Circle()
                    .stroke(
                        PushControlColors.activeForeground.opacity(PushControlStyle.primaryStrokeOpacity),
                        lineWidth: BottomNavigationLayout.primaryStrokeWidth
                    )
            }
            .shadow(
                color: PushControlColors.activeForeground.opacity(PushControlStyle.primaryGlowOpacity),
                radius: BottomNavigationLayout.primaryGlowRadius,
                y: BottomNavigationLayout.primaryGlowYOffset
            )
            .scaleEffect(isSelected ? BottomNavigationLayout.selectedPrimaryScale : 1)
    }

    private var primaryBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .background {
                Circle()
                    .fill(.white.opacity(PushGlassStyle.tintOpacity))
            }
    }
}

private struct PushGlass<Content: View>: View {
    let layout: PushAdaptiveLayout
    private let content: Content

    init(layout: PushAdaptiveLayout, @ViewBuilder content: () -> Content) {
        self.layout = layout
        self.content = content()
    }

    var body: some View {
        content
            .padding(BottomNavigationLayout.containerPadding(layout))
            .pushGlassBackground(cornerRadius: BottomNavigationLayout.containerCornerRadius(layout))
    }
}

enum BottomNavigationLayout {
    static func horizontalMargin(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 12, standard: 16, large: 20) }
    static func bottomMargin(_ layout: PushAdaptiveLayout) -> CGFloat { layout.bottomOverlayMargin }
    static func containerPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 6, standard: 7, large: 8) }
    static func containerCornerRadius(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 28, standard: 30, large: 32) }
    static let itemSpacing: CGFloat = 6
    static let labelSpacing: CGFloat = 4
    static func iconSize(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 15, standard: 16, large: 17) }
    static func itemVerticalPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 8, standard: 9, large: 10) }
    static let itemHorizontalPadding: CGFloat = 2
    static func primaryButtonSize(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 46, standard: 48, large: 50) }
    static func primaryIconSize(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 19, standard: 20, large: 21) }
    static let minimumTextScale = 0.86
    static let selectedPrimaryScale = 1.04
    static let primaryStrokeWidth: CGFloat = 1
    static let primaryGlowRadius: CGFloat = 10
    static let primaryGlowYOffset: CGFloat = 3
}
