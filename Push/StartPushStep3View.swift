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
                    timingSection
                    locationSection
                    vibeSection
                    inviteSizeSection
                }
                .padding(.horizontal, StartPushLayout.horizontalPadding)
                .padding(.bottom, StartPushLayout.contentTopSpacing)
            }

            StartPushPrimaryButton(title: "Start push", isEnabled: true, action: onNext)
                .padding(.horizontal, StartPushLayout.horizontalPadding)
                .padding(.bottom, StartPushLayout.bottomPadding)
        }
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: StartPushLayout.sectionLabelSpacing) {
            StartPushSectionLabel(title: "When?")
            HStack(spacing: 8) {
                ForEach(PushTiming.allCases, id: \.self) { option in
                    PillOptionButton(
                        title: option.title,
                        isSelected: viewModel.timing == option,
                        action: { viewModel.timing = option }
                    )
                }
            }
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

    private var vibeSection: some View {
        VStack(alignment: .leading, spacing: StartPushLayout.sectionLabelSpacing) {
            StartPushSectionLabel(title: "Vibe / Commitment")
            VStack(spacing: 8) {
                ForEach(PushVibe.allCases, id: \.self) { option in
                    PillOptionButton(
                        title: option.title,
                        isSelected: viewModel.vibe == option,
                        fullWidth: true,
                        action: { viewModel.vibe = option }
                    )
                }
            }
        }
    }

    private var inviteSizeSection: some View {
        VStack(alignment: .leading, spacing: StartPushLayout.sectionLabelSpacing) {
            StartPushSectionLabel(title: "Invite size")
            VStack(spacing: 8) {
                ForEach(PushInviteSize.allCases, id: \.self) { option in
                    PillOptionButton(
                        title: option.title,
                        isSelected: viewModel.inviteSize == option,
                        fullWidth: true,
                        action: { viewModel.inviteSize = option }
                    )
                }
            }
        }
    }
}

private struct PillOptionButton: View {
    let title: String
    let isSelected: Bool
    var fullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? PushControlColors.activeForeground : PushControlColors.textSecondary)
                .padding(.horizontal, StartPushLayout.pillHorizontalPadding)
                .padding(.vertical, StartPushLayout.pillVerticalPadding)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background(
                    Capsule().fill(isSelected
                                   ? PushControlColors.activeFill
                                   : .white.opacity(StartPushColor.rowFillOpacity))
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? PushColorPalette.Accent.walnut.opacity(StartPushColor.pillSelectedStrokeOpacity) : .clear,
                        lineWidth: StartPushLayout.pillStrokeWidth
                    )
                )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isSelected)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}
