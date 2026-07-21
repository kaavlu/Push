//
//  AddGroupStep3ReviewView.swift
//  Push
//
//  Step 3 of Add Group: final review before creating. Photo/name and the
//  member list are each tappable to jump back to the step that owns them.
//

import SwiftUI

struct AddGroupStep3ReviewView: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var viewModel: AddGroupViewModel
    let onEditPhoto: () -> Void
    let onEditMembers: () -> Void
    let onSubmit: () async -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AddGroupStep3Layout.sectionSpacing) {
                photoNameSection
                membersSection

                if let actionError = viewModel.actionError {
                    ActionErrorBanner(
                        message: actionError.message,
                        onRetry: { Task { await onSubmit() } },
                        onDismiss: { viewModel.dismissActionError() }
                    )
                }
            }
            .padding(.horizontal, StartPushLayout.horizontalPadding(layout))
            .padding(.top, AddGroupStep3Layout.contentTopPadding)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            createButton
                .padding(.horizontal, StartPushLayout.horizontalPadding(layout))
                .padding(.bottom, StartPushLayout.bottomPadding(layout))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photoNameSection: some View {
        Button(action: onEditPhoto) {
            VStack(spacing: AddGroupStep3Layout.headerSpacing) {
                GroupPhotoBadge(
                    imageAssetName: nil,
                    fallbackInitials: fallbackInitials,
                    overrideImage: viewModel.pickedImage
                )
                HStack(spacing: AddGroupStep3Layout.nameEditSpacing) {
                    Text(viewModel.groupName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PushControlColors.textEspresso)
                        .lineLimit(1)
                    Image(systemName: "pencil")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PushControlColors.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Edit group photo and name")
    }

    private var fallbackInitials: String {
        let trimmed = viewModel.groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed
            .split(separator: " ")
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: FriendsLayout.listSpacing) {
            HStack {
                FriendsSectionHeader(title: "Members", count: viewModel.totalMemberCount)
                Button(action: onEditMembers) {
                    Text("Edit")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(PushControlColors.activeForeground)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit members")
            }

            ForEach(viewModel.selectedFriends) { person in
                FriendRowCard(
                    row: AddGroupMemberRow(person: person).friendRow,
                    showsGroupLabel: false,
                    usesAvailabilityAppearance: false
                )
            }
        }
    }

    private var createButton: some View {
        Button {
            Task { await onSubmit() }
        } label: {
            ZStack {
                Text("Create group")
                    .opacity(viewModel.isSubmitting ? 0 : 1)
                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(PushControlColors.activeForeground)
                }
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(
                viewModel.isSubmitting
                    ? PushControlColors.inactiveForeground
                    : PushControlColors.activeForeground
            )
            .frame(maxWidth: .infinity)
            .frame(height: StartPushLayout.primaryButtonHeight(layout))
            .background(
                Capsule().fill(
                    viewModel.isSubmitting
                        ? PushControlColors.activeFill.opacity(0.45)
                        : PushControlColors.activeFill
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSubmitting)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isSubmitting)
        .accessibilityLabel("Create group")
    }
}

private enum AddGroupStep3Layout {
    static let sectionSpacing: CGFloat = 26
    static let contentTopPadding: CGFloat = 12
    static let headerSpacing: CGFloat = 14
    static let nameEditSpacing: CGFloat = 6
}
