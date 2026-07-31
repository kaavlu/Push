//
//  FriendDetailSheet.swift
//  Push
//

import SwiftUI

// MARK: - View Data Adapter

struct FriendDetailViewData {
    let friend: FriendPuckData

    var displayLocation: String {
        if let label = friend.locationLabel { return label }
        for prefix in ["Eating at ", "At the ", "At ", "Near "] {
            if friend.venueStatusText.hasPrefix(prefix) {
                return String(friend.venueStatusText.dropFirst(prefix.count))
            }
        }
        return friend.placeName ?? friend.venueStatusText
    }

    /// Canonical presence activity — no View-local coffee/park/gym inventing.
    var statusLine: String {
        PresenceActivityPresentation.detailStatusLine(
            activityName: friend.activity,
            venueStatusText: friend.venueStatusText
        )
    }
}

// MARK: - Sheet Root

/// Map puck detail content. Multi-person sheets add Who’s here; individual stays summary + actions.
struct FriendDetailSheet: View {
    let puck: MapPuckData
    @Binding var isMembersExpanded: Bool
    var onStartPush: (StartPushLaunchContext) -> Void = { _ in }
    var onSelectMember: (String) -> Void = { _ in }
    @State private var toastMessage: String?

    var body: some View {
        ZStack(alignment: .top) {
            FriendDetailGroupContent(
                puck: puck,
                isMembersExpanded: $isMembersExpanded,
                onDirections: { triggerToast("Opening in Maps…") },
                onAskToJoin: { triggerToast("Request sent") },
                onStartPush: { startPush() },
                onSelectMember: onSelectMember
            )

            if let message = toastMessage {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.activeForeground)
                    .padding(.horizontal, FriendDetailSheetLayout.toastHorizontalPadding)
                    .padding(.vertical, FriendDetailSheetLayout.toastVerticalPadding)
                    .pushGlassBackground(cornerRadius: FriendDetailSheetLayout.toastCornerRadius)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, FriendDetailSheetLayout.toastTopPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func triggerToast(_ message: String) {
        withAnimation(PushMotion.hangoutReveal) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(PushMotion.hangoutReveal) {
                toastMessage = nil
            }
        }
    }

    private func startPush() {
        if puck.kind == .individual, let friend = puck.people.first {
            onStartPush(.friends([friend.id], locationHint: friend.placeName))
        } else {
            onStartPush(.from(puck: puck))
        }
    }
}
