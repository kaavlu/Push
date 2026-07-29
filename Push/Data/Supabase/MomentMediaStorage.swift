//
//  MomentMediaStorage.swift
//  Push
//
//  Supabase Storage seam for Moment media (photos + video). Views never import
//  this. Mirrors ProfilePhotoStorage / GroupPhotoStorage: new object key per
//  upload, public CDN URL persisted on the row, client-side orphan rollback.
//

import Foundation
import Supabase

// `MomentMediaKind` lives in the domain layer (`Domain/Moment.swift`) — Storage
// and the repository must agree on one kind type.

/// Bytes the client wants to put in the bucket, already processed/compressed.
struct MomentMediaUpload: Equatable {
    let kind: MomentMediaKind
    let data: Data
    let contentType: String
    /// Optional video cover frame (JPEG). Nil is allowed — S2 accepts null posters.
    let posterJPEGData: Data?

    init(kind: MomentMediaKind, data: Data, contentType: String, posterJPEGData: Data? = nil) {
        self.kind = kind
        self.data = data
        self.contentType = contentType
        self.posterJPEGData = posterJPEGData
    }
}

/// Result of a successful Storage upload, before the Moment RPC commits it.
struct MomentMediaUploadResult: Equatable {
    let kind: MomentMediaKind
    /// Object key inside the `moment-media` bucket. This is what the RPCs
    /// authorize against — the server re-derives the stored URL from it.
    let objectPath: String
    /// Public HTTPS URL for local/optimistic display. `create_moment` and
    /// `append_moment_media` ignore any URL a caller sends and derive their own
    /// from the validated path (migration 0025), so this is never authoritative.
    let publicURL: String
    let posterPath: String?
    let posterURL: String?

    /// Every object this upload created — what orphan rollback must remove.
    var objectPaths: [String] { [objectPath, posterPath].compactMap { $0 } }
}

enum MomentMediaStorageError: Error, Equatable {
    case emptyData
    case unsupportedContentType(String)
    case fileTooLarge(bytes: Int, limit: Int)
}

enum MomentMediaStorageConfig {
    static let bucketID = "moment-media"
    /// Owner-scoped prefix uploads land under before `create_moment` exists.
    static let pendingPrefix = "pending"
    /// CDN-friendly cache; every upload writes a new object key.
    static let cacheControlSeconds = "3600"

    /// Named so the compose path can pick the type it just encoded to instead of
    /// indexing into the accepted lists.
    static let jpegContentType = "image/jpeg"
    static let mp4ContentType = "video/mp4"
    static let quickTimeContentType = "video/quicktime"

    static let photoContentTypes = [jpegContentType, "image/png", "image/webp"]
    static let videoContentTypes = [mp4ContentType, quickTimeContentType]
    static let posterContentType = jpegContentType
    static let posterSuffix = "-poster"
    static let posterFileExtension = "jpg"

    /// Client caps. The bucket's single server-side cap is the video ceiling
    /// (100 MiB, migration 0024); photos are held to the tighter limit here.
    static let photoMaxBytes = 10 * 1024 * 1024
    static let videoMaxBytes = 100 * 1024 * 1024

    static func allowedContentTypes(for kind: MomentMediaKind) -> [String] {
        switch kind {
        case .photo: return photoContentTypes
        case .video: return videoContentTypes
        }
    }

    static func maxBytes(for kind: MomentMediaKind) -> Int {
        switch kind {
        case .photo: return photoMaxBytes
        case .video: return videoMaxBytes
        }
    }

    /// Object key suffix per accepted mime type. Nil for anything unsupported.
    static func fileExtension(forContentType contentType: String) -> String? {
        switch contentType.lowercased() {
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/webp": return "webp"
        case "video/mp4": return "mp4"
        case "video/quicktime": return "mov"
        default: return nil
        }
    }
}

protocol MomentMediaStoring: AnyObject {
    /// Publish path: upload before any Moment row exists (`pending/{userID}/…`).
    func uploadPending(userID: String, upload: MomentMediaUpload) async throws -> MomentMediaUploadResult
    /// Append path for a tagged member of an existing Moment (`{momentID}/…`).
    func upload(momentID: String, upload: MomentMediaUpload) async throws -> MomentMediaUploadResult
    /// Best-effort removal of one object key (orphan rollback, media cleanup).
    func delete(objectPath: String) async throws
}

enum MomentMediaPath {
    static func pendingObjectPath(
        userID: String,
        fileExtension: String,
        id: UUID = UUID()
    ) -> String {
        "\(MomentMediaStorageConfig.pendingPrefix)/\(userID.lowercased())/"
            + "\(id.uuidString.lowercased()).\(fileExtension)"
    }

    static func momentObjectPath(
        momentID: String,
        fileExtension: String,
        id: UUID = UUID()
    ) -> String {
        "\(momentID.lowercased())/\(id.uuidString.lowercased()).\(fileExtension)"
    }

    /// Poster key parallel to its video: `…/{uuid}-poster.jpg`.
    static func posterObjectPath(for objectPath: String) -> String {
        let base = (objectPath as NSString).deletingPathExtension
        return "\(base)\(MomentMediaStorageConfig.posterSuffix)"
            + ".\(MomentMediaStorageConfig.posterFileExtension)"
    }

    /// Object key behind a public moment-media URL, for Storage cleanup.
    /// Non-bucket URLs (local mock paths, seed assets) return nil.
    static func storageObjectPath(from publicURL: String?) -> String? {
        guard let publicURL, !publicURL.isEmpty else { return nil }
        let marker = "/storage/v1/object/public/\(MomentMediaStorageConfig.bucketID)/"
        guard let range = publicURL.range(of: marker) else { return nil }
        let objectPath = String(publicURL[range.upperBound...])
        return objectPath.isEmpty ? nil : objectPath
    }
}

enum MomentMediaValidator {
    /// Rejects empty, oversize, or unsupported bytes before any network call,
    /// and returns the object-key extension for the accepted content type.
    @discardableResult
    static func validate(_ upload: MomentMediaUpload) throws -> String {
        guard !upload.data.isEmpty else { throw MomentMediaStorageError.emptyData }

        let contentType = upload.contentType.lowercased()
        guard MomentMediaStorageConfig.allowedContentTypes(for: upload.kind).contains(contentType),
              let fileExtension = MomentMediaStorageConfig.fileExtension(forContentType: contentType)
        else {
            throw MomentMediaStorageError.unsupportedContentType(upload.contentType)
        }

        let limit = MomentMediaStorageConfig.maxBytes(for: upload.kind)
        guard upload.data.count <= limit else {
            throw MomentMediaStorageError.fileTooLarge(bytes: upload.data.count, limit: limit)
        }
        return fileExtension
    }
}

/// Live Storage client. Keys are always `pending/{auth uid}/…` or `{moment id}/…`
/// so the 0024 RLS folder checks match.
final class SupabaseMomentMediaStorage: MomentMediaStoring {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func uploadPending(userID: String, upload: MomentMediaUpload) async throws -> MomentMediaUploadResult {
        let fileExtension = try MomentMediaValidator.validate(upload)
        let objectPath = MomentMediaPath.pendingObjectPath(
            userID: userID, fileExtension: fileExtension
        )
        return try await put(upload, at: objectPath)
    }

    func upload(momentID: String, upload: MomentMediaUpload) async throws -> MomentMediaUploadResult {
        let fileExtension = try MomentMediaValidator.validate(upload)
        let objectPath = MomentMediaPath.momentObjectPath(
            momentID: momentID, fileExtension: fileExtension
        )
        return try await put(upload, at: objectPath)
    }

    func delete(objectPath: String) async throws {
        try await PushLog.logged("moment media delete") {
            _ = try await client.storage
                .from(MomentMediaStorageConfig.bucketID)
                .remove(paths: [objectPath])
        }
    }

    /// Uploads the media bytes, then the optional poster. A failed poster upload
    /// removes the media object first so no half-item is handed to the RPC.
    private func put(_ upload: MomentMediaUpload, at objectPath: String) async throws -> MomentMediaUploadResult {
        try await PushLog.logged("moment media upload") {
            try await putObject(
                upload.data, contentType: upload.contentType, at: objectPath
            )
        }

        var posterPath: String?
        var posterURL: String?
        if let posterData = upload.posterJPEGData, !posterData.isEmpty {
            let path = MomentMediaPath.posterObjectPath(for: objectPath)
            do {
                try await PushLog.logged("moment media poster upload") {
                    try await putObject(
                        posterData,
                        contentType: MomentMediaStorageConfig.posterContentType,
                        at: path
                    )
                }
            } catch {
                try? await delete(objectPath: objectPath)
                throw error
            }
            posterPath = path
            posterURL = try publicURL(for: path)
        }

        return MomentMediaUploadResult(
            kind: upload.kind,
            objectPath: objectPath,
            publicURL: try publicURL(for: objectPath),
            posterPath: posterPath,
            posterURL: posterURL
        )
    }

    private func putObject(_ data: Data, contentType: String, at objectPath: String) async throws {
        _ = try await client.storage
            .from(MomentMediaStorageConfig.bucketID)
            .upload(
                objectPath,
                data: data,
                options: FileOptions(
                    cacheControl: MomentMediaStorageConfig.cacheControlSeconds,
                    contentType: contentType,
                    upsert: false
                )
            )
    }

    private func publicURL(for objectPath: String) throws -> String {
        try client.storage
            .from(MomentMediaStorageConfig.bucketID)
            .getPublicURL(path: objectPath)
            .absoluteString
    }
}
