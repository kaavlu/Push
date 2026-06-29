//
//  CreatePlaceholderView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI

struct CreatePlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let subtitle: String
    let symbolName: String

    var body: some View {
        ZStack {
            PushModalBackground()

            VStack(spacing: CreatePlaceholderLayout.contentSpacing) {
                Image(systemName: symbolName)
                    .font(.system(size: CreatePlaceholderLayout.iconSize, weight: .bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                    .frame(width: CreatePlaceholderLayout.iconFrame, height: CreatePlaceholderLayout.iconFrame)
                    .background(Circle().fill(PushControlColors.activeFill))

                VStack(spacing: CreatePlaceholderLayout.textSpacing) {
                    Text(title)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(PushControlColors.activeForeground)

                    Text(subtitle)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(PushControlColors.inactiveForeground)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(CreatePlaceholderLayout.cardPadding)
            .frame(maxWidth: CreatePlaceholderLayout.cardMaxWidth)
            .pushGlassBackground(cornerRadius: CreatePlaceholderLayout.cardCornerRadius)
            .padding(.horizontal, CreatePlaceholderLayout.horizontalPadding)
        }
        .safeAreaInset(edge: .top) {
            PushModalCloseButtonBar(accessibilityLabel: "Close \(title)") {
                dismiss()
            }
        }
    }
}

private enum CreatePlaceholderLayout {
    static let horizontalPadding: CGFloat = 22
    static let cardMaxWidth: CGFloat = 360
    static let cardPadding: CGFloat = 26
    static let cardCornerRadius: CGFloat = 30
    static let contentSpacing: CGFloat = 18
    static let textSpacing: CGFloat = 6
    static let iconSize: CGFloat = 24
    static let iconFrame: CGFloat = 64
}
