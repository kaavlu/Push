//
//  StartPushStep4View.swift
//  Push
//
//  Created by Manav Khanvilkar on 7/1/26.
//

import SwiftUI

struct StartPushStep4View: View {
    @ObservedObject var viewModel: StartPushViewModel
    let onViewResponses: () -> Void
    let onEdit: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: StartPushLayout.sectionSpacing) {
                confirmationIcon
                pushSummary
                responseCard
                liveStatusCard
                actionButtons
            }
            .padding(.horizontal, StartPushLayout.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, StartPushLayout.bottomPadding)
        }
    }

    private var confirmationIcon: some View {
        ZStack {
            Circle()
                .fill(PushColorPalette.Accent.sunbeam)
                .frame(width: StartPushLayout.confirmIconFrame, height: StartPushLayout.confirmIconFrame)
            Image(systemName: "checkmark")
                .font(.system(size: StartPushLayout.confirmIconSize, weight: .bold))
                .foregroundStyle(PushControlColors.activeForeground)
        }
        .shadow(
            color: PushColorPalette.Accent.walnut.opacity(0.22),
            radius: 20,
            y: 8
        )
    }

    private var pushSummary: some View {
        VStack(spacing: 8) {
            Text(viewModel.pushText.isEmpty ? "Your push" : viewModel.pushText)
                .font(.title2.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
                .multilineTextAlignment(.center)
            if !viewModel.primaryRecipientLabel.isEmpty {
                Text("Sent to \(viewModel.primaryRecipientLabel)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PushControlColors.textSecondary)
            }
            Text("Just now")
                .font(.caption.weight(.medium))
                .foregroundStyle(PushControlColors.textTertiary)
        }
    }

    private var responseCard: some View {
        VStack(spacing: StartPushLayout.responseCardSpacing) {
            HStack {
                Text("Who might be down")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PushControlColors.textEspresso)
                Spacer()
            }
            HStack(spacing: StartPushLayout.sectionSpacing) {
                responseGroup(
                    items: viewModel.likelyFreeNow,
                    label: "likely free now"
                )
                Divider()
                    .frame(height: StartPushLayout.responseDividerHeight)
                responseGroup(
                    items: viewModel.mightBeInterested,
                    label: "might be interested"
                )
            }
        }
        .padding(StartPushLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: StartPushLayout.cardCornerRadius, style: .continuous)
                .fill(.white.opacity(StartPushColor.rowFillOpacity))
        )
    }

    private func responseGroup(items: [PushRecipientItem], label: String) -> some View {
        VStack(spacing: StartPushLayout.responseGroupSpacing) {
            HStack(spacing: -8) {
                ForEach(items.prefix(3)) { item in
                    RecipientAvatarView(
                        imageAssetName: item.imageAssetName,
                        initials: item.initials,
                        size: StartPushLayout.responseAvatarSize
                    )
                    .overlay(
                        Circle().stroke(.white, lineWidth: StartPushColor.avatarOverlayStroke)
                    )
                }
            }
            Text("\(items.count) \(label)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var liveStatusCard: some View {
        HStack(spacing: 12) {
            livePulse
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Push is live")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(PushControlColors.textEspresso)
                    liveBadge
                }
                Text("We'll notify you as people respond.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PushControlColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(StartPushLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: StartPushLayout.cardCornerRadius, style: .continuous)
                .fill(.white.opacity(StartPushColor.rowFillOpacity))
        )
    }

    private var livePulse: some View {
        ZStack {
            Circle()
                .fill(PushColorPalette.Accent.sageGreen.opacity(0.28))
                .frame(
                    width: StartPushLayout.liveStatusDotSize * 2.4,
                    height: StartPushLayout.liveStatusDotSize * 2.4
                )
            Circle()
                .fill(PushColorPalette.Accent.sageGreen)
                .frame(
                    width: StartPushLayout.liveStatusDotSize,
                    height: StartPushLayout.liveStatusDotSize
                )
        }
    }

    private var liveBadge: some View {
        Text("Live")
            .font(.caption2.weight(.bold))
            .foregroundStyle(PushColorPalette.Accent.sageGreen)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(PushColorPalette.Accent.mintFoam))
    }

    private var actionButtons: some View {
        VStack(spacing: StartPushLayout.actionButtonSpacing) {
            StartPushPrimaryButton(
                title: "View live responses",
                isEnabled: true,
                action: onViewResponses
            )
            Button(action: onEdit) {
                Text("Edit push")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit push")
        }
    }
}
