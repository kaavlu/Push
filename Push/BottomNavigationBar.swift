//
//  BottomNavigationBar.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI

struct BottomNavigationBar: View {
    @Binding var selectedItem: BottomNavigationItem
    let action: (BottomNavigationItem) -> Void

    var body: some View {
        PushGlass {
            HStack(spacing: BottomNavigationLayout.itemSpacing) {
                ForEach(BottomNavigationItem.allCases) { item in
                    Button {
                        action(item)
                    } label: {
                        if item.isPrimaryAction {
                            PrimaryNavigationButtonLabel(isSelected: selectedItem == item)
                        } else {
                            BottomNavigationButtonLabel(
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
    let item: BottomNavigationItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: BottomNavigationLayout.labelSpacing) {
            Image(systemName: item.systemImageName)
                .font(.system(size: BottomNavigationLayout.iconSize, weight: .semibold))

            Text(item.title)
                .font(.caption2.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(isSelected ? PushControlColors.activeForeground : PushControlColors.inactiveForeground)
        .padding(.vertical, BottomNavigationLayout.itemVerticalPadding)
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
    let isSelected: Bool

    var body: some View {
        Image(systemName: BottomNavigationItem.create.systemImageName)
            .font(.system(size: BottomNavigationLayout.primaryIconSize, weight: .bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(
                width: BottomNavigationLayout.primaryButtonSize,
                height: BottomNavigationLayout.primaryButtonSize
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
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(BottomNavigationLayout.containerPadding)
            .pushGlassBackground(cornerRadius: BottomNavigationLayout.containerCornerRadius)
    }
}

enum BottomNavigationLayout {
    static let horizontalMargin: CGFloat = 20
    static let bottomMargin: CGFloat = 18
    static let containerPadding: CGFloat = 8
    static let containerCornerRadius: CGFloat = 32
    static let itemSpacing: CGFloat = 6
    static let labelSpacing: CGFloat = 4
    static let iconSize: CGFloat = 17
    static let itemVerticalPadding: CGFloat = 10
    static let itemHorizontalPadding: CGFloat = 2
    static let primaryButtonSize: CGFloat = 50
    static let primaryIconSize: CGFloat = 21
    static let selectedPrimaryScale = 1.04
    static let primaryStrokeWidth: CGFloat = 1
    static let primaryGlowRadius: CGFloat = 10
    static let primaryGlowYOffset: CGFloat = 3
}
