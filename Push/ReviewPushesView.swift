// Push/ReviewPushesView.swift
import SwiftUI

struct ReviewPushesView: View {
    @ObservedObject var viewModel: PlansViewModel
    /// When set, the deck shows only this push instead of the full
    /// "needs response" queue — used by a card's Manage button to let the
    /// user change a response they've already given.
    var focusPlan: PlanData? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout

    @State private var deckIndex: Int = 0
    @State private var dragOffset: CGSize = .zero

    private var currentPlan: PlanData? {
        if let focusPlan { return deckIndex == 0 ? focusPlan : nil }
        let plans = viewModel.plansNeedingResponse
        guard deckIndex < plans.count else { return nil }
        return plans[deckIndex]
    }

    var body: some View {
        ZStack {
            FriendsBackground()
            VStack(spacing: 0) {
                reviewHeader {
                    dismiss()
                }
                    .padding(.top, PlansLayout.headerTopPadding)
                Spacer()
                cardOrEmptyState
                Spacer()
                if currentPlan != nil {
                    swipeHints
                        .padding(.bottom, PlansLayout.deckHintsBottomPadding)
                }
            }
            .padding(.horizontal, PlansLayout.horizontalPadding(layout))
        }
    }

    private func reviewHeader(dismissAction: @escaping () -> Void) -> some View {
        HStack(alignment: .center) {
            Text("Review Pushes")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)
            Spacer(minLength: 0)
            PushCircleIconButton(
                systemImageName: "xmark",
                accessibilityLabel: "Close review",
                action: dismissAction
            )
        }
    }

    @ViewBuilder
    private var cardOrEmptyState: some View {
        if let plan = currentPlan {
            ReviewPushCard(plan: plan)
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
                    PushMotion.selection,
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
            swipeHint("← Pass")
            Spacer()
            swipeHint("Maybe ↑")
            Spacer()
            swipeHint("Join →")
        }
    }

    private func swipeHint(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(PushColorPalette.Accent.walnut)
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
        Task { await viewModel.respond(to: plan, with: direction) }
        if focusPlan != nil {
            dismiss()
        } else {
            deckIndex += 1
            dragOffset = .zero
        }
    }
}
