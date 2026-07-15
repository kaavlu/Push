// Push/PlansView.swift
import SwiftUI

struct PlansView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout
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
                .padding(.horizontal, PlansLayout.horizontalPadding(layout))
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
        .fullScreenCover(item: $viewModel.reviewFocusPlan) { plan in
            ReviewPushesView(viewModel: viewModel, focusPlan: plan)
        }
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlansCalendarView(viewModel: viewModel)
            Spacer(minLength: PlansLayout.calendarToYourPushesSpacing(layout))
            YourPushesModule(viewModel: viewModel)
            Spacer(minLength: PlansLayout.pushesModuleSpacing(layout))
            ActivePushesModule(viewModel: viewModel)
            Spacer(minLength: 0)
            StartPlanButton { viewModel.isStartPushPresented = true }
                .frame(maxWidth: .infinity)
                .padding(.top, PlansLayout.startButtonTopSpacing)
        }
        .padding(.horizontal, PlansLayout.horizontalPadding(layout))
        .padding(.top, PlansLayout.headerToCalendarSpacing(layout))
        .padding(.bottom, PlansLayout.startPlanButtonBottomPadding(layout))
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

            if viewModel.showsYourPushesEmptyState {
                PlansEmptyCard(
                    title: "No current pushes",
                    message: "Start a push and make your next move.",
                    messageColor: PlansColor.metadataTertiary
                )
            } else if let first = viewModel.yourPushes.first {
                YourPushCard(plan: first, onManage: {
                    viewModel.openManage(plan: first)
                }, onCancel: {
                    viewModel.cancel(plan: first)
                })
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

                if viewModel.needsResponseCount > 0 {
                    Button {
                        viewModel.isReviewDeckPresented = true
                    } label: {
                        Text("Review \(viewModel.needsResponseCount) ›")
                            .plansModuleActionText()
                    }
                    .buttonStyle(.plain)
                }
            }

            if let first = viewModel.activePushes.first {
                ActivePlanCard(plan: first, onManage: {
                    viewModel.openReview(plan: first)
                })
            } else if viewModel.showsActivePushesEmptyState {
                PlansEmptyCard(
                    title: "No active pushes",
                    message: "New invites and active pushes will show up here.",
                    messageColor: PlansColor.metadataSecondary
                )
            }
        }
    }
}

private struct PlansEmptyCard: View {
    @Environment(\.pushLayout) private var layout
    let title: String
    let message: String
    let messageColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: PlansLayout.cardRowSpacing(layout)) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(messageColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PlansLayout.cardPadding(layout))
        .frame(minHeight: PlansLayout.pushCardMinHeight(layout), alignment: .leading)
        .plansGlassCard(cornerRadius: PlansLayout.cardCornerRadius(layout))
        .accessibilityElement(children: .combine)
    }
}

struct YourPushesListView: View {
    @ObservedObject var viewModel: PlansViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout
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
                    .padding(.horizontal, PlansLayout.horizontalPadding(layout))
                ScrollView {
                    VStack(spacing: PlansLayout.currentPushesSpacing) {
                        ForEach(viewModel.yourPushes) { plan in
                            YourPushCard(plan: plan, onManage: {
                                managedPlan = plan
                            }, onCancel: {
                                viewModel.cancel(plan: plan)
                                if viewModel.yourPushes.isEmpty {
                                    dismiss()
                                }
                            })
                        }
                    }
                    .padding(.horizontal, PlansLayout.horizontalPadding(layout))
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
        .fullScreenCover(item: $managedPlan, onDismiss: dismissIfNoOwnedPushes) { plan in
            StartPushFlowView(context: .edit(plan: plan))
        }
        .onChange(of: viewModel.yourPushes.count) { count in
            if count == 0 && managedPlan == nil {
                dismiss()
            }
        }
    }

    private func dismissIfNoOwnedPushes() {
        if viewModel.yourPushes.isEmpty {
            dismiss()
        }
    }
}

private struct StartPlanButton: View {
    @Environment(\.pushLayout) private var layout
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
            .padding(.horizontal, PlansLayout.startPlanButtonHorizontalPadding(layout))
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

#if DEBUG
struct PlansView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            PlansView()
        }
    }
}
#endif
