// Push/Data/Supabase/SupabaseClientProvider.swift
import Foundation
import Supabase

/// Single shared SupabaseClient. Session persistence/restoration is handled by
/// the SDK's default local storage (Keychain on Apple platforms).
final class SupabaseClientProvider {
    static let shared = SupabaseClientProvider()
    let client: SupabaseClient

    private init() {
        client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
    }
}
