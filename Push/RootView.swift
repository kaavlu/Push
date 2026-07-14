// Push/RootView.swift
import SwiftUI

/// Pure, testable description of what the root should show.
enum BootstrapState: Equatable {
    case loading
    case gate
    case app(AuthedUser?)   // nil user = mock mode (identity comes from the seed container).

    static func initial(mode: AppMode, restored: AuthedUser?) -> BootstrapState {
        switch mode {
        case .mock: return .app(nil)
        case .live: return restored.map { .app($0) } ?? .gate
        }
    }
}

struct RootView: View {
    @StateObject private var authModel: AuthViewModel
    @State private var state: BootstrapState = .loading
    private let mode: AppMode
    private let auth: AuthService

    init(mode: AppMode = AppEnvironment.current,
         auth: AuthService = SupabaseAuthService()) {
        self.mode = mode
        self.auth = auth
        _authModel = StateObject(wrappedValue: AuthViewModel(auth: auth))
    }

    var body: some View {
        content
            .task {
                guard case .loading = state else { return }
                let restored = mode == .live ? await auth.restoreSession() : nil
                enter(.initial(mode: mode, restored: restored))
            }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            ProgressView()
        case .gate:
            AuthGateView(model: authModel) { user in enter(.app(user)) }
        case .app:
            ContentView()   // ViewModels default to AppDataContainer.shared (installed in `enter`).
        }
    }

    /// Install the live container BEFORE flipping to `.app`, so `ContentView`'s
    /// @StateObject ViewModels capture the live `.shared`, not the mock one.
    /// Mock mode keeps the default seed container.
    private func enter(_ next: BootstrapState) {
        if case .app(let user?) = next {
            AppDataContainer.installLive(
                client: SupabaseClientProvider.shared.client, currentUserID: user.id
            )
        }
        state = next
    }
}
