// Push/Data/Supabase/SupabaseClientProvider.swift
import Foundation
import Supabase

/// Single shared SupabaseClient. Session persistence/restoration is handled by
/// the SDK's default local storage (Keychain on Apple platforms).
final class SupabaseClientProvider {
    static let shared = SupabaseClientProvider()
    let client: SupabaseClient

    private init() {
        // Default redirect for recovery / confirm emails so deep links land in-app.
        let options = SupabaseClientOptions(
            auth: .init(redirectToURL: AuthRedirect.resetURL)
        )
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: options
        )
    }
}
