import Foundation

/// Reads the committed project URL + anon key from the generated Info.plist
/// (fed by Push/Config/Supabase.xcconfig). No secrets: anon key only.
enum SupabaseConfig {
    /// Every Supabase project URL resolves under this host suffix. Guards
    /// against an empty, localhost, or otherwise misconfigured
    /// `Supabase.xcconfig` value shipping silently in a Release build.
    private static let productionHostSuffix = ".supabase.co"

    static func isProductionHost(_ url: URL) -> Bool {
        url.host?.hasSuffix(productionHostSuffix) == true
    }

    static var url: URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: raw) else {
            fatalError("SupabaseURL missing/invalid in Info.plist")
        }
        guard isProductionHost(url) else {
            fatalError("SupabaseURL is not a production Supabase host: \(url.host ?? "nil")")
        }
        PushLog.bootstrap.log("Supabase host: \(url.host ?? "unknown", privacy: .public)")
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
