//
//  GroupPhotoStorage.swift
//  Push
//
//  Supabase Storage seam for group photos. Views never import this.
//

import Foundation
import Supabase

/// Result of a successful Storage upload before the group row is updated.
struct GroupPhotoUploadResult: Equatable {
    /// Object key inside the `group-photos` bucket (`{groupID}/{uuid}.jpg`).
    let objectPath: String
    /// Public HTTPS URL stored on `groups.image_asset_path`.
    let publicURL: String
}

protocol GroupPhotoStoring: AnyObject {
    func upload(groupID: String, jpegData: Data) async throws -> GroupPhotoUploadResult
    func delete(objectPath: String) async throws
}

enum GroupPhotoStorageConfig {
    static let bucketID = "group-photos"
    static let contentType = "image/jpeg"
    /// CDN-friendly cache; replacements always use a new object key.
    static let cacheControlSeconds = "3600"
}

/// Live Storage client. Upload paths are always `{group id}/{uuid}.jpg` so RLS
/// folder checks match (owner-only writes under `{group_id}/…`).
final class SupabaseGroupPhotoStorage: GroupPhotoStoring {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func upload(groupID: String, jpegData: Data) async throws -> GroupPhotoUploadResult {
        let objectPath = "\(groupID.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        _ = try await client.storage
            .from(GroupPhotoStorageConfig.bucketID)
            .upload(
                objectPath,
                data: jpegData,
                options: FileOptions(
                    cacheControl: GroupPhotoStorageConfig.cacheControlSeconds,
                    contentType: GroupPhotoStorageConfig.contentType,
                    upsert: false
                )
            )
        let publicURL = try client.storage
            .from(GroupPhotoStorageConfig.bucketID)
            .getPublicURL(path: objectPath)
        return GroupPhotoUploadResult(objectPath: objectPath, publicURL: publicURL.absoluteString)
    }

    func delete(objectPath: String) async throws {
        _ = try await client.storage
            .from(GroupPhotoStorageConfig.bucketID)
            .remove(paths: [objectPath])
    }
}

enum GroupPhotoPath {
    /// When `image_asset_path` holds a public group-photos URL, return the object key
    /// for Storage cleanup. Non-group-photos URLs / local paths return nil.
    static func storageObjectPath(from imageAssetPath: String?) -> String? {
        guard let imageAssetPath, !imageAssetPath.isEmpty else { return nil }
        let marker = "/storage/v1/object/public/\(GroupPhotoStorageConfig.bucketID)/"
        guard let range = imageAssetPath.range(of: marker) else { return nil }
        let objectPath = String(imageAssetPath[range.upperBound...])
        return objectPath.isEmpty ? nil : objectPath
    }
}
