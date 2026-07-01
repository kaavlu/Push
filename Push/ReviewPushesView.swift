// Push/ReviewPushesView.swift
import SwiftUI

struct ReviewPushesView: View {
    @ObservedObject var viewModel: PlansViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var deckIndex: Int = 0
    @State private var dragOffset: CGSize = .zero

    private var currentPlan: PlanData? {
        let plans = viewModel.plansNeedingResponse
        guard deckIndex < plans.count else { return nil }
        return plans[deckIndex]
    }

    var body: some View {
        ZStack {
            PushModalBackground()
            VStack(spacing: 0) {
                reviewHeader
                    .padding(.top, PlansLayout.headerTopPadding)
                Spacer()
                cardOrEmptyState
                Spacer()
                if currentPlan != nil {
                    swipeHints
                        .padding(.bottom, PlansLayout.deckHintsBottomPadding)
                }
                remainingLabel
                    .padding(.bottom, PlansLayout.deckRemainingLabelBottomPadding)
            }
            .padding(.horizontal, PlansLayout.horizontalPadding)
        }
        .overlay(alignment: .top) {
            PushModalCloseButtonBar(accessibilityLabel: "Close review") {
                dismiss()
            }
        }
    }

    private var reviewHeader: some View {
        Text("Review Pushes")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var cardOrEmptyState: some View {
        if let plan = currentPlan {
            ActivePlanCard(plan: plan)
                .padding(PlansLayout.deckCardPadding)
                .offset(dragOffset)
                .rotationEffect(
                    .degrees(Double(dragOffset.width) / PlansLayout.swipeRotationDivisor)
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            handleSwipeEnd(value.translation, plan: plan)
                        }
                )
                .animation(
                    .spring(response: 0.3, dampingFraction: 0.8),
                    value: dragOffset
                )
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("You're all caught up")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text("Check back later")
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
        }
    }

    private var swipeHints: some View {
        HStack {
            Text("← Pass")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PushControlColors.textTertiary)
            Spacer()
            Text("Maybe ↑")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
            Spacer()
            Text("Join →")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PushColorPalette.Accent.walnut)
        }
    }

    private var remainingLabel: some View {
        let remaining = max(0, viewModel.plansNeedingResponse.count - deckIndex)
        return Text(remaining > 0 ? "\(remaining) left" : "")
            .font(.caption)
            .foregroundStyle(PushControlColors.textTertiary)
    }

    private func handleSwipeEnd(_ translation: CGSize, plan: PlanData) {
        if translation.width > PlansLayout.swipeThreshold {
            commit(plan: plan, direction: .right)
        } else if translation.width < -PlansLayout.swipeThreshold {
            commit(plan: plan, direction: .left)
        } else if translation.height < PlansLayout.swipeUpThreshold {
            commit(plan: plan, direction: .up)
        } else {
            dragOffset = .zero
        }
    }

    private func commit(plan: PlanData, direction: SwipeDirection) {
        viewModel.respond(to: plan, with: direction)
        deckIndex += 1
        dragOffset = .zero
    }
}
