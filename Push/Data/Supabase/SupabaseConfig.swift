// Push/Data/Supabase/SupabaseConfig.swift
import Foundation

/// Reads the committed project URL + anon key from the generated Info.plist
/// (fed by Push/Config/Supabase.xcconfig). No secrets: anon key only.
enum SupabaseConfig {
    static var url: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: raw) else {
            fatalError("SupabaseURL missing/invalid in Info.plist")
        }
        return url
    }

    static var anonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
              !key.isEmpty else {
            fatalError("SupabaseAnonKey missing in Info.plist")
        }
        return key
    }
}
