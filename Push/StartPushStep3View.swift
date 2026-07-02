//
//  StartPushStep3View.swift
//  Push
//
//  Created by Manav Khanvilkar on 7/1/26.
//

import SwiftUI

struct StartPushStep3View: View {
    @ObservedObject var viewModel: StartPushViewModel
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: StartPushLayout.sectionSpacing) {
                    StartPushHeader(
                        title: "Add quick details.",
                        subtitle: "A few details help your friends respond."
                    )
                    whenSection
                    locationSection
                    notesSection
                }
                .padding(.horizontal, StartPushLayout.horizontalPadding)
                .padding(.bottom, StartPushLayout.contentTopSpacing)
            }

            StartPushPrimaryButton(title: "Start push", isEnabled: true, action: onNext)
                .padding(.horizontal, StartPushLayout.horizontalPadding)
                .padding(.bottom, StartPushLayout.bottomPadding)
        }
    }

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: StartPushLayout.sectionLabelSpacing) {
            StartPushSectionLabel(title: "When?")
            PushDatePicker(selectedDate: $viewModel.selectedTime)
            PushTimeClicker(selectedTime: $viewModel.selectedTime)
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: StartPushLayout.sectionLabelSpacing) {
            StartPushSectionLabel(title: "Where? (optional)")
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PushControlColors.textTertiary)
                TextField(
                    "e.g., Downtown, Central Park, Your place",
                    text: $viewModel.location
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PushControlColors.textEspresso)
                .tint(PushControlColors.activeForeground)
            }
            .padding(.horizontal, 14)
            .frame(height: StartPushLayout.searchBarHeight)
            .pushGlassBackground(cornerRadius: StartPushLayout.searchBarHeight / 2)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: StartPushLayout.sectionLabelSpacing) {
            StartPushSectionLabel(title: "Notes (optional)")
            ZStack(alignment: .topLeading) {
                if viewModel.notes.isEmpty {
                    Text("Dress code, what to bring, parking info...")
                        .font(.body.weight(.medium))
                        .foregroundStyle(PushControlColors.textTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $viewModel.notes)
                    .font(.body.weight(.medium))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .tint(PushControlColors.activeForeground)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: StartPushLayout.notesMinHeight)
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
        }
    }
}
