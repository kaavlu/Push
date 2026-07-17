// Push/RootView.swift
import SwiftUI

/// Environment-injected sign-out effect owned by `RootView`. A nil handler
/// means sign-out is unavailable (mock mode has no live session to end), so
/// `ProfileView` can hide the button entirely rather than show a dead one.
struct SignOutAction {
    private let handler: (() async -> Void)?

    init(handler: (() async -> Void)? = nil) { self.handler = handler }

    var isAvailable: Bool { handler != nil }

    func callAsFunction() async { await handler?() }
}

private struct SignOutActionKey: EnvironmentKey {
    static let defaultValue = SignOutAction()
}

extension EnvironmentValues {
    var signOut: SignOutAction {
        get { self[SignOutActionKey.self] }
        set { self[SignOutActionKey.self] = newValue }
    }
}

/// Pure, testable description of what the root should show.
enum BootstrapState: Equatable {
    case loading
    case gate
    case preparing(AuthedUser)
    case preparationFailed(AuthedUser, String)
    case app(AuthedUser?)   // nil user = mock mode (identity comes from the seed container).

    static func initial(mode: AppMode, restored: AuthedUser?) -> BootstrapState {
        switch mode {
        case .mock: return .app(nil)
        case .live: return restored.map { .preparing($0) } ?? .gate
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
                let initial = BootstrapState.initial(mode: mode, restored: restored)
                enter(initial)
                if case .preparing(let user) = initial { await prepare(user) }
            }
            .onOpenURL { url in
                guard mode == .live else { return }
                Task { await handleOpenURL(url) }
            }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            ProgressView()
        case .gate:
            AuthGateView(model: authModel) { user in
                enter(.preparing(user))
                Task { await prepare(user) }
            }
        case .preparing:
            LivePreparationView()
        case .preparationFailed(let user, let message):
            LivePreparationFailureView(
                message: message,
                retry: {
                    enter(.preparing(user))
                    Task { await prepare(user) }
                },
                signOut: { Task { await performSignOut() } }
            )
        case .app:
            // ViewModels default to AppDataContainer.shared (installed in `enter`).
            ContentView()
                .environment(\.signOut, signOutAction)
        }
    }

    /// Sign-out is a real effect only in live mode — mock has no session to
    /// end, and routing it to `.gate` there would attempt a real Supabase
    /// sign-in that overwrites the mock container. `ProfileView` uses
    /// `isAvailable` to hide the button entirely when this is unavailable.
    private var signOutAction: SignOutAction {
        guard mode == .live else { return SignOutAction() }
        return SignOutAction { await performSignOut() }
    }

    @MainActor
    private func performSignOut() async {
        try? await auth.signOut()
        // Clears the stale `authedUser` so `AuthGateView`'s `onChange` fires
        // again if the same user signs back in (Equatable value would
        // otherwise look unchanged and never re-trigger `onAuthenticated`).
        authModel.signOutReset()
        enter(.gate)
    }

    /// Recovery emails open `pushapp://auth/reset…`. Establish the recovery
    /// session on the service, show set-password on the gate, and leave `.app`
    /// if the user was already signed in.
    @MainActor
    private func handleOpenURL(_ url: URL) async {
        let handled = await authModel.handleOpenURL(url)
        if handled {
            enter(.gate)
        }
    }

    @MainActor
    private func prepare(_ user: AuthedUser) async {
        do {
            let container = try await AppDataContainer.prepareLive(
                client: SupabaseClientProvider.shared.client, currentUserID: user.id
            )
            AppDataContainer.installPreparedLive(container)
            enter(.app(user))
        } catch {
            enter(.preparationFailed(user, error.localizedDescription))
        }
    }

    /// Install the live container BEFORE flipping to `.app`, so `ContentView`'s
    /// @StateObject ViewModels capture the live `.shared`, not the mock one.
    /// Mock mode keeps the default seed container.
    private func enter(_ next: BootstrapState) {
        state = next
    }
}

private struct LivePreparationView: View {
    var body: some View {
        ZStack {
            FriendsBackground()
            VStack(spacing: 18) {
                Text("Push").font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(PushControlColors.textEspresso)
                ProgressView().tint(PushControlColors.textEspresso)
                Text("Getting your people together…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PushControlColors.textSecondary)
            }
        }
        .ignoresSafeArea()
    }
}

private struct LivePreparationFailureView: View {
    let message: String
    let retry: () -> Void
    let signOut: () -> Void

    var body: some View {
        ZStack {
            FriendsBackground()
            VStack(spacing: 16) {
                Text("We couldn’t get Push ready")
                    .font(.title2.bold()).foregroundStyle(PushControlColors.textEspresso)
                Text("Check your connection and try again. Your data hasn’t changed.")
                    .multilineTextAlignment(.center).foregroundStyle(PushControlColors.textSecondary)
                Button("Try Again", action: retry).buttonStyle(.borderedProminent)
                Button("Sign Out", action: signOut).foregroundStyle(PushControlColors.textSecondary)
                Text(message).font(.caption2).foregroundStyle(PushControlColors.textTertiary)
                    .lineLimit(2).multilineTextAlignment(.center)
            }
            .padding(32)
        }
        .ignoresSafeArea()
    }
}
