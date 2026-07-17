//
//  ProfilePhotoStorage.swift
//  Push
//
//  Supabase Storage seam for profile avatars. Views never import this.
//

import Foundation
import Supabase

/// Result of a successful Storage upload before the profile row is updated.
struct ProfilePhotoUploadResult: Equatable {
    /// Object key inside the `avatars` bucket (`{userID}/{uuid}.jpg`).
    let objectPath: String
    /// Public HTTPS URL stored on `profiles.image_asset_path`.
    let publicURL: String
}

protocol ProfilePhotoStoring: AnyObject {
    func upload(userID: String, jpegData: Data) async throws -> ProfilePhotoUploadResult
    func delete(objectPath: String) async throws
}

enum ProfilePhotoStorageConfig {
    static let bucketID = "avatars"
    static let contentType = "image/jpeg"
    /// CDN-friendly cache; replacements always use a new object key.
    static let cacheControlSeconds = "3600"
}

/// Live Storage client. Upload paths are always `{auth uid}/{uuid}.jpg` so RLS
/// folder checks match.
final class SupabaseProfilePhotoStorage: ProfilePhotoStoring {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func upload(userID: String, jpegData: Data) async throws -> ProfilePhotoUploadResult {
        let objectPath = "\(userID.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        _ = try await client.storage
            .from(ProfilePhotoStorageConfig.bucketID)
            .upload(
                objectPath,
                data: jpegData,
                options: FileOptions(
                    cacheControl: ProfilePhotoStorageConfig.cacheControlSeconds,
                    contentType: ProfilePhotoStorageConfig.contentType,
                    upsert: false
                )
            )
        let publicURL = try client.storage
            .from(ProfilePhotoStorageConfig.bucketID)
            .getPublicURL(path: objectPath)
        return ProfilePhotoUploadResult(objectPath: objectPath, publicURL: publicURL.absoluteString)
    }

    func delete(objectPath: String) async throws {
        _ = try await client.storage
            .from(ProfilePhotoStorageConfig.bucketID)
            .remove(paths: [objectPath])
    }
}

enum ProfilePhotoPath {
    /// When `image_asset_path` holds a public avatars URL, return the object key
    /// for Storage cleanup. Non-avatars URLs / local paths return nil.
    static func storageObjectPath(from imageAssetPath: String?) -> String? {
        guard let imageAssetPath, !imageAssetPath.isEmpty else { return nil }
        let marker = "/storage/v1/object/public/\(ProfilePhotoStorageConfig.bucketID)/"
        guard let range = imageAssetPath.range(of: marker) else { return nil }
        let objectPath = String(imageAssetPath[range.upperBound...])
        return objectPath.isEmpty ? nil : objectPath
    }
}
