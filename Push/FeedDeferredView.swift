import SwiftUI

/// Deferred Feed — cream empty state with no CTA (feature not live yet).
/// Embedded under ContentView's bottom nav; leave via the shared tab bar.
struct FeedDeferredView: View {
    @Environment(\.pushLayout) private var layout

    var body: some View {
        ZStack {
            FriendsBackground()
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                EmptySurfaceView(
                    title: EmptySurfaceCopy.feedDeferredTitle,
                    message: EmptySurfaceCopy.feedDeferredMessage,
                    systemImage: "list.bullet"
                )
                Spacer(minLength: 0)
            }
            // Keep empty-state content clear of the floating bottom nav.
            .padding(.bottom, FriendsLayout.contentBottomClearance(layout))
        }
    }
}
