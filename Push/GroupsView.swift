//
//  GroupsView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI

struct GroupsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout
    @StateObject private var viewModel: GroupsViewModel
    @State private var startPushContext: StartPushLaunchContext?

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: GroupsViewModel())
    }

    init(viewModel: GroupsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        groupsList
            // Same system slide-up / slide-down as Profile (fullScreenCover).
            .fullScreenCover(item: presentedGroupBinding) { group in
                GroupDetailHost(
                    viewModel: viewModel,
                    group: group,
                    onStartPush: { startPushContext = .group(group.id) }
                )
            }
            .fullScreenCover(item: $startPushContext) { context in
                StartPushFlowView(context: context)
            }
    }

    private var presentedGroupBinding: Binding<PushGroupData?> {
        Binding(
            get: { viewModel.group(for: viewModel.presentedGroupID) },
            set: { newValue in
                if newValue == nil {
                    viewModel.closeDetail()
                }
            }
        )
    }

    private var groupsList: some View {
        ZStack {
            PushModalBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GroupsLayout.sectionSpacing) {
                    GroupsHeader()

                    LazyVStack(spacing: GroupsLayout.cardSpacing) {
                        ForEach(viewModel.groups) { group in
                            GroupSocialCircleCard(
                                group: group,
                                stats: viewModel.stats(for: group),
                                isSelected: viewModel.isSelected(group)
                            ) {
                                viewModel.openDetail(for: group)
                            }
                        }
                    }
                }
                .padding(.horizontal, GroupsLayout.horizontalPadding(layout))
                .padding(.top, GroupsLayout.topPadding)
                .padding(.bottom, GroupsLayout.bottomPadding)
            }
        }
        .overlay(alignment: .top) {
            PushModalCloseButtonBar(accessibilityLabel: "Close groups") {
                dismiss()
            }
        }
    }
}

private struct GroupsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GroupsLayout.headerTextSpacing) {
            Text("Groups")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)

            Text("Your circles")
                .font(.callout.weight(.semibold))
                .foregroundStyle(PushControlColors.inactiveForeground)
        }
        .padding(.top, GroupsLayout.headerTopPadding)
    }
}

private struct GroupSocialCircleCard: View {
    @Environment(\.pushLayout) private var layout
    let group: PushGroupData
    let stats: [PushGroupStat]
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: GroupsLayout.cardContentSpacing) {
                GroupIdentityRow(group: group)
                GroupStatsRow(stats: stats)
            }
            .padding(GroupsLayout.cardPadding(layout))
            .frame(maxWidth: .infinity, alignment: .leading)
            .pushGlassBackground(cornerRadius: GroupsLayout.cardCornerRadius(layout))
            .overlay {
                RoundedRectangle(cornerRadius: GroupsLayout.cardCornerRadius(layout), style: .continuous)
                    .stroke(selectedStrokeColor, lineWidth: GroupsLayout.selectedStrokeWidth)
            }
            .shadow(
                color: PushColorPalette.Accent.walnut.opacity(GroupsColor.cardShadowOpacity),
                radius: GroupsLayout.cardShadowRadius,
                y: GroupsLayout.cardShadowYOffset
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.name)
        .accessibilityValue(isSelected ? "Selected" : group.status.title)
    }

    private var selectedStrokeColor: Color {
        isSelected ? PushControlColors.activeFill.opacity(GroupsColor.selectedStrokeOpacity) : .clear
    }
}

private struct GroupIdentityRow: View {
    @Environment(\.pushLayout) private var layout
    let group: PushGroupData

    var body: some View {
        HStack(alignment: .center, spacing: GroupsLayout.identitySpacing(layout)) {
            GroupProfileImage(group: group)

            VStack(alignment: .leading, spacing: GroupsLayout.identityTextSpacing) {
                Text(group.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(GroupsLayout.minimumTextScale)

                Text(memberCountText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.inactiveForeground)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            PushGroupStatusPill(title: group.status.title)
        }
    }

    private var memberCountText: String {
        "\(group.memberCount) members"
    }
}

private struct GroupProfileImage: View {
    @Environment(\.pushLayout) private var layout
    let group: PushGroupData

    var body: some View {
        GroupListAvatar(
            imageAssetName: group.imageAssetName,
            fallbackInitials: group.fallbackInitials,
            size: GroupsLayout.avatarSize(layout),
            cornerRadius: GroupsLayout.avatarCornerRadius(layout)
        )
    }
}

private struct GroupFallbackTile: View {
    let group: PushGroupData

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PushControlColors.activeFill.opacity(GroupsColor.fallbackTopOpacity),
                    .white.opacity(GroupsColor.fallbackBottomOpacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: GroupsLayout.fallbackTextSpacing) {
                Text(group.fallbackSymbol)
                    .font(.system(size: GroupsLayout.fallbackSymbolSize))

                Text(group.fallbackInitials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)
            }
        }
    }
}

// Group status → PushGroupStatusPill (DesignSystem brand sunbeam pill).

private struct GroupStatsRow: View {
    let stats: [PushGroupStat]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: GroupsLayout.statSpacing) {
                ForEach(stats) { stat in
                    GroupStatBlock(stat: stat)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GroupsLayout.statSpacing) {
                    ForEach(stats) { stat in
                        GroupStatBlock(stat: stat)
                            .frame(minWidth: GroupsLayout.compactStatMinWidth)
                    }
                }
            }
        }
    }
}

private struct GroupStatBlock: View {
    let stat: PushGroupStat

    var body: some View {
        VStack(alignment: .leading, spacing: GroupsLayout.statTextSpacing) {
            Text("\(stat.value)")
                .font(.title2.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)

            Text(stat.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PushControlColors.inactiveForeground)
                .lineLimit(1)
                .minimumScaleFactor(GroupsLayout.minimumTextScale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GroupsLayout.statPadding)
        .background {
            RoundedRectangle(cornerRadius: GroupsLayout.statCornerRadius, style: .continuous)
                .fill(.white.opacity(GroupsColor.statFillOpacity))
        }
    }
}

private enum GroupsLayout {
    static func horizontalPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.pageHorizontalPadding }
    static let topPadding: CGFloat = 16
    static let bottomPadding: CGFloat = 88
    static let sectionSpacing: CGFloat = 20
    static let headerTopPadding: CGFloat = 0
    static let headerTextSpacing: CGFloat = 3
    static let cardSpacing: CGFloat = 16
    static func cardPadding(_ layout: PushAdaptiveLayout) -> CGFloat { layout.cardPadding }
    static func cardCornerRadius(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 24, standard: 26, large: 28) }
    static let cardContentSpacing: CGFloat = 18
    static let cardShadowRadius: CGFloat = 18
    static let cardShadowYOffset: CGFloat = 8
    static let selectedStrokeWidth: CGFloat = 1.4
    static func identitySpacing(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 10, standard: 12, large: 14) }
    static let identityTextSpacing: CGFloat = 3
    static func avatarSize(_ layout: PushAdaptiveLayout) -> CGFloat { layout.avatarMedium }
    static func avatarCornerRadius(_ layout: PushAdaptiveLayout) -> CGFloat { layout.value(compact: 18, standard: 20, large: 22) }
    static let avatarStrokeWidth: CGFloat = 1
    static let fallbackSymbolSize: CGFloat = 22
    static let fallbackTextSpacing: CGFloat = 3
    static let statusHorizontalPadding: CGFloat = 11
    static let statusVerticalPadding: CGFloat = 7
    static let statSpacing: CGFloat = 8
    static let statPadding: CGFloat = 12
    static let compactStatMinWidth: CGFloat = 92
    static let statCornerRadius: CGFloat = 18
    static let statTextSpacing: CGFloat = 2
    static let minimumTextScale = 0.82
}

private enum GroupsColor {
    static let cardShadowOpacity = 0.1
    static let selectedStrokeOpacity = 0.86
    static let avatarStrokeOpacity = 0.78
    static let fallbackTopOpacity = 0.92
    static let fallbackBottomOpacity = 0.86
    static let statusFillOpacity = 0.92
    static let statFillOpacity = 0.3
}

struct GroupsView_Previews: PreviewProvider {
    static var previews: some View {
        GroupsView()
    }
}
