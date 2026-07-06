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
        .fullScreenCover(isPresented: $viewModel.isYourPushesPresented) {
            YourPushesListView(viewModel: viewModel)
        }
        .fullScreenCover(item: $viewModel.managedPlan) { plan in
            ManagePushView(plan: plan) {
                viewModel.managedPlan = nil
            }
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: PlansLayout.sectionSpacing) {
            PlansCalendarView(viewModel: viewModel)
            YourPushesModule(viewModel: viewModel)
            ActivePushesModule(viewModel: viewModel)
            Spacer(minLength: 0)
            StartPlanButton { viewModel.isStartPushPresented = true }
                .frame(maxWidth: .infinity)
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

private struct YourPushesModule: View {
    @ObservedObject var viewModel: PlansViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.currentPushesSpacing) {
            Text("Your Pushes")
                .font(.headline.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            if let first = viewModel.yourPushes.first {
                YourPushCard(plan: first) {
                    viewModel.openManage(plan: first)
                }
            }
            if viewModel.yourPushes.count > 1 {
                seeAllButton
            }
        }
    }

    private var seeAllButton: some View {
        Button {
            viewModel.isYourPushesPresented = true
        } label: {
            Text("See all \(viewModel.yourPushes.count) →")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .padding(.top, PlansLayout.reviewAllButtonTopPadding)
    }
}

private struct ActivePushesModule: View {
    @ObservedObject var viewModel: PlansViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.currentPushesSpacing) {
            Text("Active Pushes")
                .font(.headline.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            if let first = viewModel.activePushes.first {
                ActivePlanCard(plan: first)
            }
            if viewModel.activePushes.count > 1 {
                reviewAllButton
            }
        }
    }

    private var reviewAllButton: some View {
        Button {
            viewModel.isReviewDeckPresented = true
        } label: {
            Text("Review all \(viewModel.activePushes.count) →")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .padding(.top, PlansLayout.reviewAllButtonTopPadding)
    }
}

struct YourPushesListView: View {
    @ObservedObject var viewModel: PlansViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PushModalBackground()
            VStack(alignment: .leading, spacing: 0) {
                Text("Your Pushes")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, PlansLayout.headerTopPadding)
                    .padding(.horizontal, PlansLayout.horizontalPadding)
                ScrollView {
                    VStack(spacing: PlansLayout.currentPushesSpacing) {
                        ForEach(viewModel.yourPushes) { plan in
                            YourPushCard(plan: plan) {
                                viewModel.openManage(plan: plan)
                            }
                        }
                    }
                    .padding(.horizontal, PlansLayout.horizontalPadding)
                    .padding(.top, PlansLayout.sectionSpacing)
                    .padding(.bottom, PlansLayout.bottomPadding)
                }
            }
        }
        .overlay(alignment: .top) {
            PushModalCloseButtonBar(accessibilityLabel: "Close your pushes") {
                dismiss()
            }
        }
    }
}

private struct StartPlanButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("+ Start Push")
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)
                .padding(.horizontal, PlansLayout.startPlanButtonHorizontalPadding)
                .frame(height: PlansLayout.startPlanButtonHeight)
                .pushGlassBackground(cornerRadius: PlansLayout.startPlanButtonCornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start a new push")
    }
}
