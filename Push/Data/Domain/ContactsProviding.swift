// Push/Data/Domain/ContactsProviding.swift
import Foundation

/// App-owned contacts authorization (not CNAuthorizationStatus).
enum ContactsAuthorizationState: String, Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

/// In-memory hint for matching people already on Push — never uploaded bulk.
struct ContactMatchHint: Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    /// Digits only when available; matching v1 prefers display name search.
    let phoneDigits: String?
}

/// Device contacts edge. Live uses Contacts framework; tests inject fakes.
@MainActor
protocol ContactsProviding: AnyObject {
    func authorizationState() -> ContactsAuthorizationState
    func requestAccess() async -> Bool
    func fetchMatchHints(limit: Int) async throws -> [ContactMatchHint]
}

/// No-op provider (tests / when Contacts unavailable).
@MainActor
final class NullContactsProvider: ContactsProviding {
    func authorizationState() -> ContactsAuthorizationState { .denied }
    func requestAccess() async -> Bool { false }
    func fetchMatchHints(limit: Int) async throws -> [ContactMatchHint] { [] }
}

/// Test double with fixed hints and controllable grant.
@MainActor
final class FixedContactsProvider: ContactsProviding {
    var grantAccess: Bool
    var hints: [ContactMatchHint]
    private(set) var requestAccessCount = 0

    init(grantAccess: Bool = true, hints: [ContactMatchHint] = []) {
        self.grantAccess = grantAccess
        self.hints = hints
    }

    func authorizationState() -> ContactsAuthorizationState {
        grantAccess ? .authorized : .denied
    }

    func requestAccess() async -> Bool {
        requestAccessCount += 1
        return grantAccess
    }

    func fetchMatchHints(limit: Int) async throws -> [ContactMatchHint] {
        Array(hints.prefix(limit))
    }
}
