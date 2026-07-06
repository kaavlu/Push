//
//  StartPushStep2View.swift
//  Push
//
//  Created by Manav Khanvilkar on 7/1/26.
//

import SwiftUI

struct StartPushStep2View: View {
    @ObservedObject var viewModel: StartPushViewModel
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: StartPushLayout.sectionSpacing) {
                    StartPushHeader(
                        title: "What's the push?",
                        subtitle: "Write your plan or idea. Keep it short and fun."
                    )
                    textArea
                    suggestionSection
                }
                .padding(.horizontal, StartPushLayout.horizontalPadding)
                .padding(.bottom, StartPushLayout.contentTopSpacing)
            }

            StartPushPrimaryButton(title: "Next", isEnabled: viewModel.canAdvanceStep2, action: onNext)
                .padding(.horizontal, StartPushLayout.horizontalPadding)
                .padding(.bottom, StartPushLayout.bottomPadding)
        }
    }

    private var textArea: some View {
        VStack(alignment: .trailing, spacing: StartPushLayout.charCounterSpacing) {
            ZStack(alignment: .topLeading) {
                if viewModel.pushText.isEmpty {
                    Text("e.g. \"Grab coffee?\" or \"Late dinner in 30?\"")
                        .font(.body.weight(.medium))
                        .foregroundStyle(PushControlColors.textTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $viewModel.pushText)
                    .font(.body.weight(.medium))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .tint(PushControlColors.activeForeground)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: StartPushLayout.textAreaMinHeight)
            }
            .padding(StartPushLayout.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: StartPushLayout.cardCornerRadius, style: .continuous)
                    .fill(.white.opacity(StartPushColor.textEditorFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: StartPushLayout.cardCornerRadius, style: .continuous)
                    .stroke(PushColorPalette.Accent.walnut.opacity(StartPushColor.textEditorStrokeOpacity), lineWidth: 1)
            )

            Text("\(viewModel.characterCount)/\(viewModel.pushTextMaxCount)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(viewModel.characterCount >= viewModel.pushTextMaxCount
                                 ? PushColorPalette.Accent.walnut
                                 : PushControlColors.textTertiary)
        }
    }

    private var suggestionSection: some View {
        VStack(alignment: .leading, spacing: StartPushLayout.sectionLabelSpacing) {
            StartPushSectionLabel(title: "Quick ideas")
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: StartPushLayout.suggestionChipSpacing
            ) {
                ForEach(pushSuggestions, id: \.self) { suggestion in
                    SuggestionChip(text: suggestion) {
                        applySuggestion(suggestion)
                    }
                }
            }
        }
    }

    private func applySuggestion(_ text: String) {
        if viewModel.pushText.isEmpty {
            viewModel.pushText = text
        } else {
            let trimmed = viewModel.pushText.trimmingCharacters(in: .whitespaces)
            let joined = "\(trimmed), \(text)"
            viewModel.pushText = String(joined.prefix(viewModel.pushTextMaxCount))
        }
    }
}

private struct SuggestionChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, StartPushLayout.pillVerticalPadding)
                .background(Capsule().fill(PushControlColors.activeFill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
    }
}
