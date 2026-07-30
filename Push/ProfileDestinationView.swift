//
//  ProfileDestinationView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI

struct ProfileDestinationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout
    let route: ProfileRoute
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        ZStack {
            PushModalBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: ProfileLayout.sectionSpacing(layout)) {
                    ProfileDestinationHeader(route: route)
                    if let actionError = viewModel.actionError {
                        ActionErrorBanner(
                            message: actionError.message,
                            onRetry: { viewModel.retryActionError() },
                            onDismiss: { viewModel.dismissActionError() }
                        )
                    }
                    destinationContent
                }
                .padding(.horizontal, ProfileLayout.horizontalPadding(layout))
                .padding(.top, ProfileLayout.topPadding)
                .padding(.bottom, ProfileLayout.bottomPadding)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack {
                ProfileBackButton { dismiss() }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, ProfileLayout.horizontalPadding(layout))
            .padding(.top, ProfileLayout.closeTopPadding)
            .padding(.bottom, ProfileLayout.closeBottomPadding)
        }
    }

    @ViewBuilder
    private var destinationContent: some View {
        switch route {
        case .editProfile:
            ProfileEditScreen(viewModel: viewModel)
        case .activityVisibility:
            ProfileToggleList(items: viewModel.activityVisibility) { id in
                viewModel.toggleActivityVisibility(id: id)
            }
        case .mapPreferences:
            ProfileToggleList(items: viewModel.mapPreferences) { id in
                viewModel.toggleMapPreference(id: id)
            }
        case .closeFriends:
            ProfileToggleList(items: viewModel.closeFriends) { id in
                viewModel.toggleCloseFriend(id: id)
            }
        }
    }
}

private struct ProfileDestinationHeader: View {
    let route: ProfileRoute

    var body: some View {
        GlassCard {
            HStack(spacing: ProfileLayout.rowIconSpacing) {
                StatusIcon(symbolName: route.symbolName)
                ProfileRowText(title: route.title, subtitle: route.subtitle)
                Spacer(minLength: 0)
            }
        }
    }
}

private struct ProfileEditScreen: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ProfileLayout.fieldSpacing) {
                SectionTitle("Basics")
                ProfileTextField(title: "Name", text: $viewModel.displayName)
                ProfileTextField(title: "Handle", text: $viewModel.handle)
                Button {
                    viewModel.beginPhotoEditing()
                } label: {
                    ProfileRowContent(
                        symbolName: "camera.fill",
                        title: "Profile photo",
                        subtitle: viewModel.hasProfilePhoto
                            ? "Change or remove your photo"
                            : "Add a photo from your library",
                        trailingSymbolName: "chevron.right"
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isPhotoBusy)
            }
        }
        // Fields bind directly to the view model's @Published state for a live
        // preview as the user types; the write only fires once on navigating
        // away, avoiding a request per keystroke (and mid-edit `handle` writes
        // that would collide with the column's unique constraint).
        .onDisappear {
            viewModel.setProfileBasics(
                name: viewModel.displayName,
                handle: viewModel.handle
            )
        }
    }
}

private struct ProfileTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileLayout.rowTextSpacing) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(PushControlColors.inactiveForeground)
            TextField(title, text: $text)
                .font(.body.weight(.semibold))
                .foregroundStyle(PushControlColors.activeForeground)
                .textInputAutocapitalization(.words)
                .padding(ProfileLayout.fieldPadding)
                .background(
                    RoundedRectangle(cornerRadius: ProfileLayout.fieldCornerRadius, style: .continuous)
                        .fill(.white.opacity(ProfileColor.rowFillOpacity))
                )
        }
    }
}

private struct ProfileToggleList: View {
    let items: [ProfileToggleItem]
    let toggle: (String) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ProfileLayout.rowSpacing) {
                ForEach(items) { item in
                    ProfileToggleRow(item: item) {
                        toggle(item.id)
                    }
                }
            }
        }
    }
}
