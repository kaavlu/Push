// Push/Data/Supabase/SocialAuthSignIn.swift
import AuthenticationServices
import Foundation

/// Errors specific to native social presentation (not GoTrue).
enum SocialAuthError: Error, Equatable {
    case cancelled
    case missingIDToken
    case unavailable
}

enum SocialAuthCancellation {
    /// True when the user dismissed the Google web session without completing.
    static func isCancellation(_ error: Error) -> Bool {
        if let social = error as? SocialAuthError, social == .cancelled { return true }
        if let webError = error as? ASWebAuthenticationSessionError,
           webError.code == .canceledLogin
        {
            return true
        }
        return false
    }
}
