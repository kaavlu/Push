// Push/Data/Supabase/SocialAuthSignIn.swift
import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Errors specific to native social presentation (not GoTrue).
enum SocialAuthError: Error, Equatable {
    case cancelled
    case missingIDToken
    case unavailable
}

/// Result of a native Apple credential request before Supabase exchange.
struct AppleIDTokenResult: Equatable {
    let idToken: String
    let rawNonce: String
    let fullName: PersonNameComponents?
}

/// Presents the system Sign in with Apple sheet and returns an identity token + nonce.
@MainActor
enum AppleIDTokenRequester {
    static func request() async throws -> AppleIDTokenResult {
        let rawNonce = randomNonce()
        let hashedNonce = sha256(rawNonce)

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = AppleSignInDelegate(continuation: continuation, rawNonce: rawNonce)
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            // Retain delegate for the lifetime of the system sheet.
            AppleSignInDelegateStore.shared.retain(delegate)
            controller.performRequests()
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                // Fallback if secure random fails; still non-empty for the request.
                randoms = (0..<16).map { _ in UInt8.random(in: 0...255) }
            }
            for byte in randoms where remaining > 0 {
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Delegate plumbing

private final class AppleSignInDelegateStore {
    static let shared = AppleSignInDelegateStore()
    private var retained: [ObjectIdentifier: AppleSignInDelegate] = [:]

    func retain(_ delegate: AppleSignInDelegate) {
        retained[ObjectIdentifier(delegate)] = delegate
    }

    func release(_ delegate: AppleSignInDelegate) {
        retained.removeValue(forKey: ObjectIdentifier(delegate))
    }
}

private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    private var continuation: CheckedContinuation<AppleIDTokenResult, Error>?
    private let rawNonce: String

    init(continuation: CheckedContinuation<AppleIDTokenResult, Error>, rawNonce: String) {
        self.continuation = continuation
        self.rawNonce = rawNonce
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let key = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return key
        }
        return scenes.flatMap(\.windows).first ?? ASPresentationAnchor()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { finish() }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            resume(throwing: SocialAuthError.unavailable)
            return
        }
        guard
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            !idToken.isEmpty
        else {
            resume(throwing: SocialAuthError.missingIDToken)
            return
        }
        resume(
            returning: AppleIDTokenResult(
                idToken: idToken,
                rawNonce: rawNonce,
                fullName: credential.fullName
            )
        )
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        defer { finish() }
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            resume(throwing: SocialAuthError.cancelled)
            return
        }
        resume(throwing: error)
    }

    private func resume(returning value: AppleIDTokenResult) {
        continuation?.resume(returning: value)
        continuation = nil
    }

    private func resume(throwing error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    private func finish() {
        AppleSignInDelegateStore.shared.release(self)
    }
}

enum SocialAuthCancellation {
    /// True when the user dismissed Apple or the Google web session without completing.
    static func isCancellation(_ error: Error) -> Bool {
        if let social = error as? SocialAuthError, social == .cancelled { return true }
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return true
        }
        if let webError = error as? ASWebAuthenticationSessionError,
           webError.code == .canceledLogin
        {
            return true
        }
        return false
    }
}
