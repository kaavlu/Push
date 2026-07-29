//
//  MomentMediaFileStore.swift
//  Push
//
//  Mock-mode on-disk home for Moment media (mirrors GroupPhotoFileStore).
//  Keeps the same object-key layout as the live bucket so path-shape rules are
//  exercised identically in DEBUG and tests.
//

import Foundation

enum MomentMediaFileStore {
    private static let folderName = MomentMediaStorageConfig.bucketID

    static func fileURL(objectPath: String) throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = root
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent(objectPath, isDirectory: false)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        return url
    }

    @discardableResult
    static func save(objectPath: String, data: Data) throws -> URL {
        let url = try fileURL(objectPath: objectPath)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func remove(objectPath: String) {
        guard let url = try? fileURL(objectPath: objectPath) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

/// Mock `MomentMediaStoring`: same keys and validation as live, local files
/// instead of a bucket. `publicURL` is a local file path, which `AvatarImageLoader`
/// already resolves.
final class LocalMomentMediaStorage: MomentMediaStoring {
    func uploadPending(userID: String, upload: MomentMediaUpload) async throws -> MomentMediaUploadResult {
        let fileExtension = try MomentMediaValidator.validate(upload)
        let objectPath = MomentMediaPath.pendingObjectPath(
            userID: userID, fileExtension: fileExtension
        )
        return try write(upload, at: objectPath)
    }

    func upload(momentID: String, upload: MomentMediaUpload) async throws -> MomentMediaUploadResult {
        let fileExtension = try MomentMediaValidator.validate(upload)
        let objectPath = MomentMediaPath.momentObjectPath(
            momentID: momentID, fileExtension: fileExtension
        )
        return try write(upload, at: objectPath)
    }

    /// Idempotent, matching the live client: removing an absent key is not an error.
    func delete(objectPath: String) async throws {
        MomentMediaFileStore.remove(objectPath: objectPath)
    }

    private func write(_ upload: MomentMediaUpload, at objectPath: String) throws -> MomentMediaUploadResult {
        let url = try MomentMediaFileStore.save(objectPath: objectPath, data: upload.data)

        var posterPath: String?
        var posterURL: String?
        if let posterData = upload.posterJPEGData, !posterData.isEmpty {
            let path = MomentMediaPath.posterObjectPath(for: objectPath)
            posterURL = try MomentMediaFileStore.save(objectPath: path, data: posterData).path
            posterPath = path
        }

        return MomentMediaUploadResult(
            kind: upload.kind,
            objectPath: objectPath,
            publicURL: url.path,
            posterPath: posterPath,
            posterURL: posterURL
        )
    }
}
