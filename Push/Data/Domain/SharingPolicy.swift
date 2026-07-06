//
//  SharingPolicy.swift
//  Push
//

import Foundation

/// What does person A share with person B in context C.
/// Resolution order: friend-specific → group → globalDefault.
struct SharingPolicy: Identifiable, Codable, Equatable {
    enum AudienceType: String, Codable { case friend, group, globalDefault }
    enum LocationVisibility: String, Codable { case exact, vague, hidden }
    enum DetailVisibility: String, Codable { case full, vague, hidden }
    enum AvailabilityVisibility: String, Codable { case full, hidden }

    let id: String
    let ownerPersonID: Person.ID
    let audienceType: AudienceType
    let audienceID: String?
    let locationVisibility: LocationVisibility
    let activityVisibility: DetailVisibility
    let availabilityVisibility: AvailabilityVisibility
    let expiresAt: Date?
}
