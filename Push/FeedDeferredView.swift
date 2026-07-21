import SwiftUI

/// Full-screen deferred Feed — cream empty state with no CTA (feature not live yet).
struct FeedDeferredView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout

    var body: some View {
        ZStack {
            FriendsBackground()
            VStack(spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    FriendsCircleButton(
                        systemImageName: "xmark",
                        accessibilityLabel: "Close Feed",
                        action: { dismiss() }
                    )
                }
                .padding(.horizontal, FriendsLayout.horizontalPadding(layout))
                .padding(.top, FriendsLayout.topPadding)
                Spacer(minLength: 0)
                EmptySurfaceView(
                    title: EmptySurfaceCopy.feedDeferredTitle,
                    message: EmptySurfaceCopy.feedDeferredMessage,
                    systemImage: "list.bullet"
                )
                Spacer(minLength: 0)
            }
        }
    }
}
