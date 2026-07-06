//
//  Person.swift
//  Push
//

import Foundation

/// Canonical person. IDs are stable and opaque: seed IDs are readable slugs
/// for convenience, production IDs will be UUID/ULID/database IDs. Never
/// derive identity from display names outside the seed file.
struct Person: Identifiable, Codable, Equatable {
    let id: String
    let firstName: String
    let imageAssetPath: String?

    var displayName: String {
        firstName.prefix(1).uppercased() + firstName.dropFirst()
    }

    var initials: String {
        String(firstName.prefix(2)).uppercased()
    }
}
