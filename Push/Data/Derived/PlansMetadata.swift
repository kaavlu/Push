//
//  PlansMetadata.swift
//  Push
//
//  Shared "·"-joining rule for card metadata rows. Live data can leave a
//  value (group, location, ...) empty, and a naive string interpolation
//  would show a dangling "· " with nothing on one side — this keeps the
//  separator scoped to only the values that are actually present.
//

import Foundation

enum PlansMetadata {
    static let separator = " · "

    /// Joins non-empty, trimmed parts with " · ". Empty or whitespace-only
    /// parts are dropped entirely, so a missing value never leaves a
    /// dangling dot or extra spacing.
    static func joined(_ parts: [String]) -> String {
        parts
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }
}
