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

/// Environment-injected account deletion owned by `RootView`. Unavailable in
/// mock (no Auth user). Throws on backend failure so Profile can show a
/// recoverable error without leaving `.app`.
struct DeleteAccountAction {
    private let handler: (() async throws -> Void)?

    init(handler: (() async throws -> Void)? = nil) { self.handler = handler }

    var isAvailable: Bool { handler != nil }

    func callAsFunction() async throws {
        guard let handler else { return }
        try await handler()
    }
}

private struct DeleteAccountActionKey: EnvironmentKey {
    static let defaultValue = DeleteAccountAction()
}

extension EnvironmentValues {
    var deleteAccount: DeleteAccountAction {
        get { self[DeleteAccountActionKey.self] }
        set { self[DeleteAccountActionKey.self] = newValue }
    }
}

/// Pure, testable description of what the root should show.
enum BootstrapState: Equatable {
    case loading
    case gate
    case preparing(AuthedUser)
    case preparationFailed(AuthedUser, String)
    /// Live first-run setup (privacy / location / notifications / friends).
    case onboarding(AuthedUser)
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
                PushLog.logStartupBanner(mode: mode)
                let restored = mode == .live ? await auth.restoreSession() : nil
                if mode == .live {
                    PushLog.bootstrap.log("session restore: \(restored != nil, privacy: .public)")
                }
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
        case .onboarding:
            PostAuthOnboardingView {
                if case .onboarding(let user) = state {
                    enter(.app(user))
                } else {
                    enter(.app(authModel.authedUser))
                }
            }
            .environment(\.signOut, signOutAction)
            .environment(\.deleteAccount, deleteAccountAction)
        case .app:
            // ViewModels default to AppDataContainer.shared (installed in `enter`).
            ContentView()
                .environment(\.signOut, signOutAction)
                .environment(\.deleteAccount, deleteAccountAction)
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

    private var deleteAccountAction: DeleteAccountAction {
        guard mode == .live else { return DeleteAccountAction() }
        return DeleteAccountAction { try await performDeleteAccount() }
    }

    @MainActor
    private func performSignOut() async {
        // Unpublish → location shutdown → mock container before killing JWT / gate
        // so presence cannot outlive the authenticated session (Issue #69 / §2.9.1).
        await AppDataContainer.shutdownSharedAndReinstallMock()
        try? await auth.signOut()
        // Clears the stale `authedUser` so `AuthGateView`'s `onChange` fires
        // again if the same user signs back in (Equatable value would
        // otherwise look unchanged and never re-trigger `onAuthenticated`).
        authModel.signOutReset()
        enter(.gate)
    }

    /// RPC must succeed before local teardown or gate transition. On failure the
    /// user stays signed in with a live location session (recoverable).
    @MainActor
    private func performDeleteAccount() async throws {
        try await auth.deleteAccount()
        // Server cascade removes presence; skip client unpublish, still stop pipeline.
        await AppDataContainer.shutdownSharedAndReinstallMock(attemptUnpublish: false)
        authModel.signOutReset()
        enter(.gate)
    }

    /// Recovery: `pushapp://auth/reset…` → set-password on the gate.
    /// OAuth: `pushapp://auth/callback…` → signed-in user → prepare/app.
    @MainActor
    private func handleOpenURL(_ url: URL) async {
        let handled = await authModel.handleOpenURL(url)
        guard handled else { return }
        if let user = authModel.authedUser, !authModel.pendingPasswordRecovery {
            enter(.preparing(user))
            await prepare(user)
        } else {
            enter(.gate)
        }
    }

    @MainActor
    private func prepare(_ user: AuthedUser) async {
        do {
            let container = try await AppDataContainer.prepareLive(
                client: SupabaseClientProvider.shared.client, currentUserID: user.id
            )
            // Fail closed: do not enter .app without knowing completion status.
            // Skip location start when onboarding is still required so the OS
            // permission prompt is not raced before the onboarding location step.
            let needsOnboarding: Bool
            do {
                needsOnboarding = try await container.profile.needsPostAuthOnboarding()
            } catch {
                PushLog.bootstrap.error(
                    "needsPostAuthOnboarding failed: \(PushLog.safeDescription(for: error), privacy: .public)"
                )
                enter(.preparationFailed(user, AuthUserMessage.generic))
                return
            }
            AppDataContainer.installPreparedLive(
                container,
                startLocationIfEligible: !needsOnboarding
            )
            // Sign-up may have held a JPEG until the session + profile row exist.
            await uploadPendingSignUpPhotoIfNeeded(using: container)
            PushLog.bootstrap.log("live data ready")
            if needsOnboarding {
                PushLog.bootstrap.log("post-auth onboarding required")
                enter(.onboarding(user))
            } else {
                enter(.app(user))
            }
        } catch {
            PushLog.bootstrap.error("live data preparation failed: \(PushLog.safeDescription(for: error), privacy: .public)")
            enter(.preparationFailed(user, error.localizedDescription))
        }
    }

    /// Best-effort avatar upload after signup (or first sign-in post-confirm).
    /// Failure must not block entering the app — Profile can retry.
    @MainActor
    private func uploadPendingSignUpPhotoIfNeeded(using container: AppDataContainer) async {
        guard let jpeg = authModel.consumePendingProfilePhoto() else { return }
        do {
            try await container.profile.updateProfilePhoto(jpegData: jpeg)
            PushLog.bootstrap.log("sign-up profile photo uploaded")
        } catch {
            PushLog.bootstrap.error(
                "sign-up profile photo upload failed: \(PushLog.safeDescription(for: error), privacy: .public)"
            )
        }
    }

    /// Install the live container BEFORE flipping to `.app`, so `ContentView`'s
    /// @StateObject ViewModels capture the live `.shared`, not the mock one.
    /// Mock mode keeps the default seed container.
    private func enter(_ next: BootstrapState) {
        state = next
        // App-lifetime location: start when the authenticated (or mock) app shell
        // is shown. Live install already calls startIfEligible; mock needs this
        // so `--sim-location` dogfood runs without map ownership.
        if case .app = next {
            Task { await AppDataContainer.shared.locationSession?.startIfEligible() }
        }
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
                PushSolidSunbeamButton(title: "Try Again", action: retry)
                Button("Sign Out", action: signOut).foregroundStyle(PushControlColors.textSecondary)
                Text(message).font(.caption2).foregroundStyle(PushControlColors.textTertiary)
                    .lineLimit(2).multilineTextAlignment(.center)
            }
            .padding(32)
        }
        .ignoresSafeArea()
    }
}
