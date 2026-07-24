// Push/PlansHistoryView.swift
// Month History list + read-only detail for completed Pushes.
import SwiftUI

struct PlansHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout
    @ObservedObject var viewModel: PlansViewModel

    var body: some View {
        ZStack {
            FriendsBackground()
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, PlansLayout.horizontalPadding(layout))
                    .padding(.top, PlansLayout.headerTopPadding)
                    .padding(.bottom, PlansLayout.moduleTitleCardSpacing)

                if viewModel.historyItems.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("History")
                .font(.title2.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: PlansHistoryLayout.closeIconSize, weight: .semibold))
                    .foregroundStyle(PushControlColors.textSecondary)
                    .frame(
                        width: PlansHistoryLayout.closeTapSize,
                        height: PlansHistoryLayout.closeTapSize
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close history")
        }
    }

    private var list: some View {
        ScrollView {
            // Same list rhythm as Friends (`FriendsLayout.listSpacing` + page padding).
            // Rows are display-only for now — no detail modal on tap.
            LazyVStack(spacing: FriendsLayout.listSpacing) {
                ForEach(viewModel.historyItems) { item in
                    HistoryListRow(item: item)
                }
            }
            .padding(.horizontal, FriendsLayout.horizontalPadding(layout))
            .padding(.bottom, PlansLayout.startPlanButtonBottomPadding(layout))
        }
    }

    private var emptyState: some View {
        VStack(spacing: PlansHistoryLayout.emptySpacing) {
            Spacer()
            Text("No completed Pushes this month")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
                .multilineTextAlignment(.center)
            Text("When a Push finishes, it shows up here.")
                .font(.footnote)
                .foregroundStyle(PushControlColors.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, PlansLayout.horizontalPadding(layout))
        .frame(maxWidth: .infinity)
    }
}

// History list row → PushHistoryRow (HistoryListRow typealias).

private enum PlansHistoryLayout {
    static let closeIconSize: CGFloat = 14
    static let closeTapSize: CGFloat = 32
    static let emptySpacing: CGFloat = 8
}
