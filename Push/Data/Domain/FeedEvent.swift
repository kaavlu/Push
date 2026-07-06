//
//  FeedEvent.swift
//  Push
//

import Foundation

/// Materialized read model generated from canonical facts (presence, plans,
/// responses). Seeded manually for now; generated once a feed UI exists.
struct FeedEvent: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case arrived, becameFree, groupForming, pushCreated }

    let id: String
    let kind: Kind
    let actorIDs: [Person.ID]
    let placeID: Place.ID?
    let groupID: FriendGroup.ID?
    let timestamp: Date
}
