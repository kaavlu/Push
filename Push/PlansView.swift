// Push/PlansView.swift
import SwiftUI

struct PlansView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlansViewModel

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: PlansViewModel())
    }

    init(viewModel: PlansViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            FriendsBackground()
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
            StartPushFlowView(context: .edit(plan: plan))
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlansCalendarView(viewModel: viewModel)
            Spacer(minLength: PlansLayout.calendarToYourPushesSpacing)
            YourPushesModule(viewModel: viewModel)
            Spacer(minLength: PlansLayout.pushesModuleSpacing)
            ActivePushesModule(viewModel: viewModel)
            Spacer(minLength: 0)
            StartPlanButton { viewModel.isStartPushPresented = true }
                .frame(maxWidth: .infinity)
                .padding(.top, PlansLayout.startButtonTopSpacing)
        }
        .padding(.horizontal, PlansLayout.horizontalPadding)
        .padding(.top, PlansLayout.headerToCalendarSpacing)
        .padding(.bottom, PlansLayout.startPlanButtonBottomPadding)
    }
}

private struct PlansPageHeader: View {
    let dismissAction: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: PlansLayout.headerSubtitleSpacing) {
                Text("Pushes")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)

                Text("Plan your next move")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(PushControlColors.inactiveForeground)
            }
            Spacer()
            Button(action: dismissAction) {
                Image(systemName: "xmark")
                    .font(.system(size: ProfileLayout.closeIconSize, weight: .bold))
                    .foregroundStyle(PushColorPalette.Accent.walnut)
                    .frame(width: ProfileLayout.closeButtonSize, height: ProfileLayout.closeButtonSize)
                    .pushGlassBackground(cornerRadius: ProfileLayout.closeButtonSize / 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close pushes")
        }
        // Match the Friends screen's header-to-top spacing exactly.
        .padding(.top, FriendsLayout.topPadding)
    }
}

private struct YourPushesModule: View {
    @ObservedObject var viewModel: PlansViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.moduleTitleCardSpacing) {
            HStack(alignment: .center) {
                Text("Your Pushes")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PushControlColors.textEspresso)

                Spacer(minLength: 0)

                if viewModel.yourPushes.count > 1 {
                    Button {
                        viewModel.isYourPushesPresented = true
                    } label: {
                        Text("See all \(viewModel.yourPushes.count) ›")
                            .plansModuleActionText()
                    }
                    .buttonStyle(.plain)
                }
            }

            if let first = viewModel.yourPushes.first {
                YourPushCard(plan: first) {
                    viewModel.openManage(plan: first)
                }
            }
        }
    }
}

private struct ActivePushesModule: View {
    @ObservedObject var viewModel: PlansViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.moduleTitleCardSpacing) {
            HStack(alignment: .center) {
                Text("Active Pushes")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PushControlColors.textEspresso)

                Spacer(minLength: 0)

                if viewModel.activePushes.count > 1 {
                    Button {
                        viewModel.isReviewDeckPresented = true
                    } label: {
                        Text("Review \(viewModel.activePushes.count) ›")
                            .plansModuleActionText()
                    }
                    .buttonStyle(.plain)
                }
            }

            if let first = viewModel.activePushes.first {
                ActivePlanCard(plan: first)
            }
        }
    }
}

struct YourPushesListView: View {
    @ObservedObject var viewModel: PlansViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var managedPlan: PlanData?

    var body: some View {
        ZStack {
            FriendsBackground()
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
                                managedPlan = plan
                            }
                        }
                    }
                    .padding(.horizontal, PlansLayout.horizontalPadding)
                    .padding(.top, PlansLayout.listHeaderToCardsSpacing)
                    .padding(.bottom, PlansLayout.bottomPadding)
                }
            }
        }
        .overlay(alignment: .top) {
            PushModalCloseButtonBar(accessibilityLabel: "Close your pushes") {
                dismiss()
            }
        }
        .fullScreenCover(item: $managedPlan) { plan in
            StartPushFlowView(context: .edit(plan: plan))
        }
    }
}

private struct StartPlanButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 17, weight: .bold))
                Text("Start Push")
                    .font(.headline.weight(.bold))
            }
            // Brown accenting, no near-black espresso text.
            .foregroundStyle(PushColorPalette.Accent.walnut)
            .padding(.horizontal, PlansLayout.startPlanButtonHorizontalPadding)
            .frame(height: PlansLayout.startPlanButtonHeight)
            .background {
                Capsule()
                    .fill(PlansColor.primaryGlow)
                    .blur(radius: 16)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            // True liquid-glass control treatment (glassEffect on iOS 26+),
            // matching the header buttons rather than the flat cream cards.
            .pushGlassBackground(cornerRadius: PlansLayout.startPlanButtonCornerRadius)
            .overlay {
                RoundedRectangle(cornerRadius: PlansLayout.startPlanButtonCornerRadius, style: .continuous)
                    .stroke(PlansColor.startButtonBorder, lineWidth: PlansColor.startButtonBorderWidth)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start a new push")
    }
}

private extension Text {
    func plansModuleActionText() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(PushColorPalette.Accent.walnut)
    }
}
