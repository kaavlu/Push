// Push/PlansView.swift
import SwiftUI

struct PlansView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlansViewModel

    init(viewModel: PlansViewModel = PlansViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            PushModalBackground()
            pageContent
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            PlansPageHeader(dismissAction: { dismiss() })
                .padding(.horizontal, PlansLayout.horizontalPadding)
        }
        .fullScreenCover(isPresented: $viewModel.isReviewDeckPresented) {
            ReviewPushesView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $viewModel.isStartPushPresented) {
            StartPushFlowView()
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: PlansLayout.sectionSpacing) {
            PlansCalendarView(viewModel: viewModel)
            CurrentPushesModule(viewModel: viewModel)
            Spacer(minLength: 0)
            StartPlanButton { viewModel.isStartPushPresented = true }
                .padding(.horizontal, PlansLayout.startPlanButtonHorizontalPadding)
        }
        .padding(.horizontal, PlansLayout.horizontalPadding)
        .padding(.top, PlansLayout.topPadding)
        .padding(.bottom, PlansLayout.startPlanButtonBottomPadding)
    }
}

private struct PlansPageHeader: View {
    let dismissAction: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text("Pushes")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)
            Spacer()
            Button(action: dismissAction) {
                Image(systemName: "xmark")
                    .font(.system(size: ProfileLayout.closeIconSize, weight: .bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                    .frame(width: ProfileLayout.closeButtonSize, height: ProfileLayout.closeButtonSize)
                    .pushGlassBackground(cornerRadius: ProfileLayout.closeButtonSize / 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close pushes")
        }
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("+ Start Push")
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .frame(maxWidth: .infinity)
                .frame(height: PlansLayout.startPlanButtonHeight)
                .background(
                    Capsule().fill(PushColorPalette.Accent.sunbeam)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start a new push")
    }
}
