//
//  PushLog.swift
//  Push
//
//  Structured logging for live startup and Supabase backend failures.
//
//  Redaction rule: never log an error's `.localizedDescription`, or a
//  `PostgrestError`'s `.message` / `.detail` / `.hint` — PostgREST
//  constraint-violation messages can embed user input (e.g. a duplicate
//  handle in a unique-violation message). Only the error's Swift type name,
//  and for `PostgrestError` its stable `.code` (a Postgres error code like
//  "23505", never user data), are safe to log.
//
//  `os.Logger` treats interpolated values as `.private` (shown as
//  `<private>` in Console) unless marked `privacy: .public`. Everything
//  interpolated below has already been redacted by this file, so every
//  interpolation is explicitly `.public`.
//

import Foundation
import Supabase
import os

enum PushLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.manav.Push"

    static let bootstrap = Logger(subsystem: subsystem, category: "bootstrap")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let auth = Logger(subsystem: subsystem, category: "auth")

    static func safeDescription(for error: Error) -> String {
        let typeName = String(describing: type(of: error))
        if let postgrestError = error as? PostgrestError, let code = postgrestError.code {
            return "\(typeName)(code: \(code))"
        }
        return typeName
    }

    /// Runs `operation`, logging a one-line failure (label + safe error
    /// description) to `category` before rethrowing. Success is a silent
    /// passthrough — this only adds a logging side effect on failure.
    @discardableResult
    static func logged<T>(
        _ label: String,
        category: Logger = network,
        operation: () async throws -> T
    ) async rethrows -> T {
        do {
            return try await operation()
        } catch {
            category.error("\(label, privacy: .public) failed: \(safeDescription(for: error), privacy: .public)")
            throw error
        }
    }

    static func logStartupBanner(mode: AppMode) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        bootstrap.log("Push \(version, privacy: .public) (\(build, privacy: .public)) launching, mode=\(String(describing: mode), privacy: .public)")
    }
}
