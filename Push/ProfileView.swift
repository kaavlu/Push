//
//  ProfileView.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout
    @Environment(\.signOut) private var signOut
    @StateObject private var viewModel: ProfileViewModel
    @State private var navigationPath: [ProfileRoute] = []
    @State private var isSignOutConfirmationPresented = false
    @State private var isSigningOut = false
    private let onClose: (() -> Void)?

    @MainActor
    init(onClose: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel())
        self.onClose = onClose
    }

    init(viewModel: ProfileViewModel, onClose: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                PushModalBackground()
                profileContent
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                ProfileDestinationView(route: route, viewModel: viewModel)
            }
        }
        .safeAreaInset(edge: .top) {
            if navigationPath.isEmpty {
                PushModalCloseButtonBar(accessibilityLabel: "Close profile") {
                    closeProfile()
                }
            }
        }
        .alert("Profile photo editing", isPresented: $viewModel.isPhotoEditorPresented) {
            Button("Done", role: .cancel) {
            }
        } message: {
            Text("Photo editing is local-only in this prototype.")
        }
        .alert(item: $viewModel.connectorAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("Got it"))
            )
        }
        .confirmationDialog(
            "Sign out?",
            isPresented: $isSignOutConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) { performSignOut() }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var profileContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ProfileLayout.sectionSpacing(layout)) {
                ProfileHeader(
                    name: viewModel.displayName,
                    handle: viewModel.handle,
                    initials: viewModel.initials,
                    imageAssetName: viewModel.profileImageAssetName,
                    statusTitle: viewModel.selectedStatusTitle,
                    statusSymbolName: viewModel.selectedStatusSymbolName
                ) {
                    viewModel.beginPhotoEditing()
                }
                AvailabilityOptionsCard(viewModel: viewModel)
                ProfileRoutesCard(title: "Settings", routes: viewModel.settingsRoutes)
                ProfileRoutesCard(title: "Privacy", routes: viewModel.privacyRoutes)
                ProfileConnectCard(viewModel: viewModel)
                ProfileLegalCard(destinations: viewModel.legalDestinations)
                if signOut.isAvailable {
                    SignOutButton(isBusy: isSigningOut) {
                        isSignOutConfirmationPresented = true
                    }
                    .padding(.top, ProfileLayout.signOutTopPadding)
                }
            }
            .padding(.horizontal, ProfileLayout.horizontalPadding(layout))
            .padding(.top, ProfileLayout.topPadding)
            .padding(.bottom, ProfileLayout.bottomPadding)
        }
    }

    private func closeProfile() {
        onClose?()
        dismiss()
    }

    /// Guards against double-tap (e.g. a second confirmation while the first
    /// sign-out is still in flight) and drives the busy state around the
    /// async `signOut` effect injected by `RootView`.
    private func performSignOut() {
        guard !isSigningOut else { return }
        isSigningOut = true
        Task {
            await signOut()
            isSigningOut = false
        }
    }
}

private struct ProfileLegalCard: View {
    let destinations: [LegalDestination]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ProfileLayout.rowSpacing) {
                SectionTitle("Legal")
                ForEach(destinations) { destination in
                    Link(destination: destination.url) {
                        ProfileRowContent(
                            symbolName: destination.symbolName,
                            title: destination.title,
                            subtitle: destination.subtitle,
                            trailingSymbolName: "arrow.up.right"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(destination.title)
                    .accessibilityHint("Opens in your browser")
                }
            }
        }
    }
}

private struct AvailabilityOptionsCard: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ProfileLayout.rowSpacing) {
                SectionTitle("Set Status")
                ForEach(viewModel.statusOptions) { option in
                    StatusOptionRow(
                        option: option,
                        isSelected: viewModel.isSelected(option)
                    ) {
                        viewModel.select(option)
                    }
                    .animation(
                        .spring(response: ProfileLayout.selectionAnimationResponse, dampingFraction: ProfileLayout.selectionAnimationDamping),
                        value: viewModel.selectedStatusID
                    )
                }
            }
        }
    }
}

private struct StatusOptionRow: View {
    let option: ProfileStatusOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ProfileRowContent(
                symbolName: option.symbolName,
                title: option.title,
                subtitle: option.subtitle,
                trailingSymbolName: isSelected ? "checkmark.circle.fill" : "circle"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct ProfileRoutesCard: View {
    let title: String
    let routes: [ProfileRoute]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ProfileLayout.rowSpacing) {
                SectionTitle(title)
                ForEach(routes) { route in
                    ProfileRouteRow(route: route)
                }
            }
        }
    }
}

private struct ProfileConnectCard: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ProfileLayout.rowSpacing) {
                SectionTitle("Connect")
                ForEach(viewModel.connectors) { connector in
                    ProfileConnectorRow(connector: connector) {
                        viewModel.connect(connector)
                    }
                }
            }
        }
    }
}

private struct ProfileConnectorRow: View {
    let connector: ProfileConnector
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ProfileLayout.connectorButtonSpacing) {
            ProfileRowContent(
                symbolName: connector.symbolName,
                title: connector.title,
                subtitle: connector.subtitle,
                trailingSymbolName: "link"
            )
            Text(connector.permissionCopy)
                .font(.caption.weight(.medium))
                .foregroundStyle(PushControlColors.inactiveForeground)
                .fixedSize(horizontal: false, vertical: true)
            Button(connector.buttonTitle, action: action)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PushControlColors.activeForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ProfileLayout.pillVerticalPadding)
                .background(Capsule().fill(PushControlColors.activeFill))
        }
        .padding(ProfileLayout.rowPadding)
        .background(
            RoundedRectangle(cornerRadius: ProfileLayout.rowCornerRadius, style: .continuous)
                .fill(.white.opacity(ProfileColor.rowFillOpacity))
        )
    }
}

private struct SignOutButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ProfileLayout.signOutSpacing) {
                if isBusy {
                    ProgressView()
                } else {
                    Text("Sign Out")
                        .font(.subheadline.weight(.bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ProfileLayout.signOutVerticalPadding)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
        .disabled(isBusy)
        .accessibilityLabel("Sign out")
    }
}

#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            ProfileView()
                .environment(\.signOut, SignOutAction { })
        }
    }
}
#endif
