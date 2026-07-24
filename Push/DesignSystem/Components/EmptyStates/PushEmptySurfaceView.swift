//
//  PushEmptySurfaceView.swift
//  Push
//
//  DS-071 — full-page empty / loading / failed for ivory and modal content areas.
//  CTAs use branded primaries only (DS-002 / DS-003).
//

import SwiftUI

/// Full-page empty presentation: icon, title, optional message, optional primary CTA.
struct EmptySurfaceView: View {
    let title: String
    var message: String? = nil
    var systemImage: String = "person.2"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    /// When false, fills remaining height (centered) instead of top-padding layout.
    var expandsVertically: Bool = false

    var body: some View {
        VStack(spacing: EmptySurfaceLayout.contentSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: EmptySurfaceLayout.iconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textTertiary)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textPrimary)
                .multilineTextAlignment(.center)
            if let message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(PushControlColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                PushSolidSunbeamButton(title: actionTitle, action: action)
                    .padding(.top, EmptySurfaceLayout.actionTopPadding)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: expandsVertically ? .infinity : nil)
        .padding(.horizontal, EmptySurfaceLayout.horizontalPadding)
        .padding(.top, expandsVertically ? 0 : EmptySurfaceLayout.topPadding)
        .accessibilityElement(children: .combine)
    }
}

/// Full-page loading and hard-load failure for primary surfaces.
enum EmptySurfaceStateView {
    static var loading: some View {
        VStack(spacing: EmptySurfaceLayout.contentSpacing) {
            ProgressView().tint(PushControlColors.activeForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    static func loading(message: String) -> some View {
        VStack(spacing: EmptySurfaceLayout.contentSpacing) {
            ProgressView().tint(PushControlColors.activeForeground)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    /// Hard load failure. Prefer `surface:` for "Couldn't load …" titles, or pass
    /// an explicit `title` when the surface verb differs (e.g. "Couldn't search").
    static func failed(
        surface: String,
        retry: @escaping () -> Void
    ) -> some View {
        failed(
            title: EmptySurfaceCopy.failedTitle(surface: surface),
            message: EmptySurfaceCopy.failedMessage,
            retry: retry
        )
    }

    static func failed(
        title: String,
        message: String = EmptySurfaceCopy.failedMessage,
        retry: @escaping () -> Void
    ) -> some View {
        VStack(spacing: EmptySurfaceLayout.contentSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: EmptySurfaceLayout.iconSize, weight: .semibold))
                .foregroundStyle(PushControlColors.textSecondary)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
            PushSolidSunbeamButton(title: EmptySurfaceCopy.retryAction, action: retry)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, EmptySurfaceLayout.horizontalPadding)
    }
}

/// Friends / Groups list empty (and inline search no-match) convenience.
struct FriendsEmptyState: View {
    let mode: FriendsMode
    let isSearching: Bool
    var onAddFriends: (() -> Void)? = nil

    var body: some View {
        EmptySurfaceView(
            title: title,
            message: message,
            systemImage: icon,
            actionTitle: actionTitle,
            action: actionTitle == nil ? nil : onAddFriends
        )
    }

    private var icon: String {
        if isSearching { return "magnifyingglass" }
        return mode == .friends ? "person.2" : "person.3"
    }

    private var title: String {
        if isSearching { return EmptySurfaceCopy.searchNoMatchTitle }
        return mode == .friends
            ? EmptySurfaceCopy.friendsEmptyTitle
            : EmptySurfaceCopy.groupsEmptyTitle
    }

    private var message: String {
        if isSearching { return EmptySurfaceCopy.searchNoMatchMessage }
        return mode == .friends
            ? EmptySurfaceCopy.friendsEmptyMessage
            : EmptySurfaceCopy.groupsEmptyMessage
    }

    private var actionTitle: String? {
        guard !isSearching, mode == .friends, onAddFriends != nil else { return nil }
        return EmptySurfaceCopy.addFriendsAction
    }
}

#if DEBUG
struct PushEmptySurfaceView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            VStack(spacing: 24) {
                EmptySurfaceView(
                    title: EmptySurfaceCopy.friendsEmptyTitle,
                    message: EmptySurfaceCopy.friendsEmptyMessage,
                    actionTitle: EmptySurfaceCopy.addFriendsAction,
                    action: {}
                )
                EmptySurfaceStateView.loading(message: EmptySurfaceCopy.friendsLoading)
                EmptySurfaceStateView.failed(surface: "friends", retry: {})
            }
            .background(PushIvoryPageBackground())
        }
    }
}
#endif
