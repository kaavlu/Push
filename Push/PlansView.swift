// Push/PlansView.swift
import SwiftUI

struct PlansView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlansViewModel

    init(viewModel: PlansViewModel = PlansViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PushModalBackground()
            scrollContent
            StartPlanButton()
                .padding(.horizontal, PlansLayout.startPlanButtonHorizontalPadding)
                .padding(.bottom, PlansLayout.startPlanButtonBottomPadding)
        }
        .overlay(alignment: .top) {
            PushModalCloseButtonBar(accessibilityLabel: "Close plans") {
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $viewModel.isReviewDeckPresented) {
            // ReviewPushesView placeholder — wired in Task 7
            Text("Review Pushes").onTapGesture { viewModel.isReviewDeckPresented = false }
        }
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PlansLayout.sectionSpacing) {
                PlansPageHeader()
                PlansCalendarView(viewModel: viewModel)
                CurrentPushesModule(viewModel: viewModel)
            }
            .padding(.horizontal, PlansLayout.horizontalPadding)
            .padding(.top, PlansLayout.topPadding)
            .padding(.bottom, PlansLayout.bottomPadding)
        }
    }
}

private struct PlansPageHeader: View {
    var body: some View {
        Text("Plans")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(PushControlColors.activeForeground)
            .padding(.top, PlansLayout.headerTopPadding)
    }
}

private struct CurrentPushesModule: View {
    @ObservedObject var viewModel: PlansViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.currentPushesSpacing) {
            summaryRow
            ForEach(previewPlans) { plan in
                ActivePlanCard(plan: plan)
            }
            if viewModel.activeCount > CurrentPushesConstants.previewLimit {
                reviewAllButton
            }
        }
    }

    private var summaryRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Current Pushes")
                .font(.headline.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text("\(viewModel.activeCount) active · \(viewModel.needsResponseCount) need you")
                .font(.footnote)
                .foregroundStyle(PushControlColors.textSecondary)
        }
    }

    private var previewPlans: [PlanData] {
        Array(viewModel.sortedPlans.prefix(CurrentPushesConstants.previewLimit))
    }

    private var reviewAllButton: some View {
        Button {
            viewModel.isReviewDeckPresented = true
        } label: {
            Text("Review all \(viewModel.activeCount) →")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.top, PlansLayout.reviewAllButtonTopPadding)
    }
}

private enum CurrentPushesConstants {
    static let previewLimit = 2
}

private struct StartPlanButton: View {
    var body: some View {
        Button {
            // start plan flow — deferred to future issue
        } label: {
            Text("+ Start Plan")
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .frame(maxWidth: .infinity)
                .frame(height: PlansLayout.startPlanButtonHeight)
                .background(
                    Capsule().fill(PushColorPalette.Accent.sunbeam)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start a new plan")
    }
}
