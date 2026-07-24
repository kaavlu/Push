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
    /// Retry only the photo upload after create already succeeded.
    let onRetryPhoto: () async -> Void
    /// Dismiss with the created group and no session photo.
    let onContinueWithoutPhoto: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AddGroupStep3Layout.sectionSpacing) {
                photoNameSection
                membersSection

                if let actionError = viewModel.actionError {
                    ActionErrorBanner(
                        message: actionError.message,
                        onRetry: {
                            Task {
                                if viewModel.lastCreatedGroupID != nil {
                                    await onRetryPhoto()
                                } else {
                                    await onSubmit()
                                }
                            }
                        },
                        onDismiss: {
                            if viewModel.lastCreatedGroupID != nil {
                                onContinueWithoutPhoto()
                            } else {
                                viewModel.dismissActionError()
                            }
                        }
                    )
                    if viewModel.lastCreatedGroupID != nil {
                        Button(action: onContinueWithoutPhoto) {
                            Text("Continue without photo")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PushControlColors.textEspresso)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Continue without photo")
                    }
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
        PushSolidSunbeamButton(
            title: "Create group",
            isEnabled: !viewModel.isSubmitting,
            isLoading: viewModel.isSubmitting
        ) {
            Task { await onSubmit() }
        }
    }
}

private enum AddGroupStep3Layout {
    static let sectionSpacing: CGFloat = 26
    static let contentTopPadding: CGFloat = 12
    static let headerSpacing: CGFloat = 14
    static let nameEditSpacing: CGFloat = 6
}
