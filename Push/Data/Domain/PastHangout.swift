//
//  PastHangout.swift
//  Push
//

import Foundation

/// Recorded fact: a hangout that happened.
/// Calendar aggregates derive from these rows.
struct PastHangout: Identifiable, Codable, Equatable {
    let id: String
    let date: Date
    let participantIDs: [Person.ID]
    let note: String
    let timeRange: String
    let cameFromPush: Bool
}
