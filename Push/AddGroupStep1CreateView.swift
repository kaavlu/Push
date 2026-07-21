//
//  AddGroupStep1CreateView.swift
//  Push
//
//  Step 1 of Add Group: photo + name. The photo badge doubles as a
//  PhotosPicker button — tapping the camera badge (or anywhere on the
//  photo) opens the system picker.
//

import PhotosUI
import SwiftUI

struct AddGroupStep1CreateView: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var viewModel: AddGroupViewModel
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AddGroupStep1Layout.sectionSpacing) {
                photoPicker
                nameField
            }
            .padding(.horizontal, StartPushLayout.horizontalPadding(layout))
            .padding(.top, AddGroupStep1Layout.contentTopPadding)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StartPushPrimaryButton(
                title: "Choose members",
                isEnabled: viewModel.canAdvanceStep1,
                action: onNext
            )
            .padding(.horizontal, StartPushLayout.horizontalPadding(layout))
            .padding(.bottom, StartPushLayout.bottomPadding(layout))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $viewModel.pickedPhotoItem, matching: .images) {
            GroupPhotoBadge(
                imageAssetName: nil,
                fallbackInitials: fallbackInitials,
                overrideImage: viewModel.pickedImage
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose group photo")
        .frame(maxWidth: .infinity, alignment: .center)
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

    private var nameField: some View {
        VStack(alignment: .leading, spacing: AddGroupStep1Layout.fieldLabelSpacing) {
            StartPushSectionLabel(title: "Group name")
            HStack {
                TextField("e.g. Weekend Crew", text: $viewModel.groupName)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .tint(PushControlColors.activeForeground)
            }
            .padding(.horizontal, FriendsLayout.searchHorizontalPadding)
            .padding(.vertical, AddGroupStep1Layout.fieldVerticalPadding)
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
    }
}

private enum AddGroupStep1Layout {
    static let sectionSpacing: CGFloat = 28
    static let contentTopPadding: CGFloat = 12
    static let fieldLabelSpacing: CGFloat = 10
    static let fieldVerticalPadding: CGFloat = 13
}
