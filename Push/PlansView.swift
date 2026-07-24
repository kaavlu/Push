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
            ScrollView {
                pageContent
            }
            .refreshable {
                await viewModel.refresh()
            }

            // Full-bleed bottom popup (edge-to-edge width), not a nested system sheet.
            if let day = viewModel.selectedDay {
                DayDetailBottomSheet(day: day) {
                    viewModel.selectedDay = nil
                }
                .transition(.identity)
                .zIndex(1)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            PlansPageHeader(dismissAction: { dismiss() })
                .padding(.horizontal, PlansLayout.horizontalPadding(layout))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let actionError = viewModel.actionError {
                ActionErrorBanner(
                    message: actionError.message,
                    onRetry: { Task { await viewModel.retryLastAction() } },
                    onDismiss: { viewModel.dismissActionError() }
                )
                .padding(.horizontal, PlansLayout.horizontalPadding(layout))
                .padding(.bottom, PlansLayout.startPlanButtonBottomPadding(layout))
            }
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
        .fullScreenCover(isPresented: $viewModel.isHistoryPresented) {
            PlansHistoryView(viewModel: viewModel)
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
            PushGlassRimButton(
                title: "Start Push",
                systemImageName: "plus.circle.fill",
                accessibilityLabel: "Start a new push"
            ) {
                viewModel.isStartPushPresented = true
            }
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
        PushCreamPageHeader(title: "Pushes", subtitle: "Plan your next move") {
            PushCircleIconButton(
                systemImageName: "xmark",
                accessibilityLabel: "Close pushes",
                action: dismissAction
            )
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
                    Task { await viewModel.cancel(plan: first) }
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
                                Task {
                                    await viewModel.cancel(plan: plan)
                                    if viewModel.yourPushes.isEmpty {
                                        dismiss()
                                    }
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

private extension Text {
    /// Prefer `pushTextLinkStyle` (DS-062).
    func plansModuleActionText() -> some View {
        pushTextLinkStyle()
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
