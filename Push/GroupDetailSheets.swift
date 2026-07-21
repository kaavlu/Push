//
//  GroupDetailSheets.swift
//  Push
//
//  Invite multi-select and transfer-ownership pickers for Group Detail.
//

import SwiftUI

struct GroupInviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let candidates: [Person]
    let onInvite: ([String]) -> Void

    @State private var selectedIDs: Set<String> = []
    @State private var searchText = ""

    private var filtered: [Person] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return candidates }
        return candidates.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.firstName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FriendsBackground()
                VStack(spacing: 0) {
                    searchField
                        .padding(.horizontal, GroupDetailLayout.horizontalPadding)
                        .padding(.top, GroupDetailManageLayout.sheetHeaderTop)
                        .padding(.bottom, GroupDetailManageLayout.sheetSearchBottom)
                    candidateList
                }
            }
            .navigationTitle("Invite friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PushControlColors.textEspresso)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Invite") {
                        onInvite(Array(selectedIDs))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(PushControlColors.textEspresso)
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: FriendsLayout.searchSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: FriendsLayout.searchIconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textTertiary)
            TextField("Search friends", text: $searchText)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: FriendsLayout.searchIconSize, weight: .semibold))
                        .foregroundStyle(PushControlColors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, FriendsLayout.searchHorizontalPadding)
        .padding(.vertical, FriendsLayout.searchVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: FriendsLayout.searchCornerRadius, style: .continuous)
                .fill(FriendsColor.cardCream.opacity(FriendsColor.cardCreamOpacity))
        )
        .overlay {
            RoundedRectangle(cornerRadius: FriendsLayout.searchCornerRadius, style: .continuous)
                .stroke(
                    PushColorPalette.Accent.walnut.opacity(FriendsColor.chipStrokeWalnutOpacity),
                    lineWidth: FriendsColor.cardStrokeWidth
                )
        }
    }

    private var candidateList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: FriendsLayout.listSpacing) {
                if filtered.isEmpty {
                    FriendsEmptyState(mode: .friends, isSearching: !searchText.isEmpty)
                } else {
                    ForEach(filtered) { person in
                        inviteRow(person)
                    }
                }
            }
            .padding(.horizontal, GroupDetailLayout.horizontalPadding)
            .padding(.bottom, GroupDetailManageLayout.sheetListBottom)
        }
    }

    private func inviteRow(_ person: Person) -> some View {
        let isSelected = selectedIDs.contains(person.id)
        return FriendRowCard(
            row: person.groupInviteFriendRow,
            showsGroupLabel: false,
            usesAvailabilityAppearance: false,
            customTrailing: AnyView(selectionIndicator(isSelected: isSelected)),
            action: {
                if isSelected {
                    selectedIDs.remove(person.id)
                } else {
                    selectedIDs.insert(person.id)
                }
            }
        )
        .background {
            RoundedRectangle(cornerRadius: FriendsLayout.cardCornerRadius, style: .continuous)
                .fill(
                    PushControlColors.activeFill.opacity(
                        isSelected ? GroupDetailManageColor.selectedTintOpacity : 0
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: FriendsLayout.cardCornerRadius, style: .continuous)
                .stroke(
                    PushControlColors.activeFill.opacity(
                        isSelected ? GroupDetailManageColor.selectedStrokeOpacity : 0
                    ),
                    lineWidth: GroupDetailManageLayout.selectedStrokeWidth
                )
        }
        .animation(.easeInOut(duration: 0.16), value: isSelected)
    }

    @ViewBuilder
    private func selectionIndicator(isSelected: Bool) -> some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: StartPushLayout.selectionCircleSize, weight: .bold))
                .foregroundStyle(PushControlColors.activeForeground)
        } else {
            Image(systemName: "circle")
                .font(.system(size: StartPushLayout.selectionCircleSize, weight: .regular))
                .foregroundStyle(PushControlColors.textTertiary)
        }
    }
}

struct GroupTransferSheet: View {
    @Environment(\.dismiss) private var dismiss
    let candidates: [PushGroupMemberData]
    let onSelect: (PushGroupMemberData) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                FriendsBackground()
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: FriendsLayout.listSpacing) {
                        ForEach(candidates) { member in
                            FriendRowCard(
                                row: member.friendRow,
                                showsGroupLabel: false,
                                action: {
                                    onSelect(member)
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, GroupDetailLayout.horizontalPadding)
                    .padding(.top, GroupDetailManageLayout.sheetHeaderTop)
                    .padding(.bottom, GroupDetailManageLayout.sheetListBottom)
                }
            }
            .navigationTitle("Transfer ownership")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PushControlColors.textEspresso)
                }
            }
        }
    }
}

extension Person {
    var groupInviteFriendRow: FriendRowModel {
        FriendRowModel(
            id: id,
            friend: FriendPuckData(
                id: id,
                name: displayName,
                avatarPlaceholder: initials,
                profileImageAssetName: imageAssetPath,
                activity: "",
                activitySymbolName: "",
                activityDisplayText: "",
                availability: .unavailable,
                venueStatusText: "",
                lastUpdated: ""
            ),
            groupLabel: nil
        )
    }
}
