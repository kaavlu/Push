//
//  GroupRow.swift
//  Push
//

import Foundation

/// PostgREST row shape for `groups`. Property names match the table's
/// snake_case columns directly so no `CodingKeys` are needed.
struct GroupRow: Decodable {
    let id: String
    let name: String
    let image_asset_path: String?

    func friendGroup() -> FriendGroup {
        FriendGroup(id: id, name: name, imageAssetPath: image_asset_path)
    }
}
