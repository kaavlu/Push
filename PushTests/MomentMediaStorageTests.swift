//
//  MomentMediaStorageTests.swift
//  PushTests
//
//  Moments S3: object-key layout, client validation, mock file store, and the
//  upload → RPC → orphan-rollback sequence. No MomentRepository or Feed fixtures.
//

import Foundation
import XCTest
@testable import Push

final class MomentMediaStorageTests: XCTestCase {

    // MARK: - Path layout

    func testPendingObjectPathUsesLowercasedOwnerFolder() {
        let id = UUID()
        let path = MomentMediaPath.pendingObjectPath(
            userID: "AB12CD34-0000-0000-0000-000000000001", fileExtension: "jpg", id: id
        )
        XCTAssertEqual(
            path,
            "pending/ab12cd34-0000-0000-0000-000000000001/\(id.uuidString.lowercased()).jpg"
        )
        XCTAssertEqual(path.split(separator: "/").count, 3)
    }

    func testMomentObjectPathIsMomentFolderPlusUUID() {
        let id = UUID()
        let momentID = UUID().uuidString
        let path = MomentMediaPath.momentObjectPath(
            momentID: momentID, fileExtension: "mp4", id: id
        )
        XCTAssertEqual(path, "\(momentID.lowercased())/\(id.uuidString.lowercased()).mp4")
    }

    func testPosterPathIsParallelToItsVideo() {
        let path = MomentMediaPath.posterObjectPath(for: "pending/user/abc.mov")
        XCTAssertEqual(path, "pending/user/abc-poster.jpg")
    }

    func testStorageObjectPathParsesPublicBucketURLOnly() {
        let url = "https://tzzvwjhvjduyqywlszqc.supabase.co"
            + "/storage/v1/object/public/moment-media/pending/u/1.jpg"
        XCTAssertEqual(MomentMediaPath.storageObjectPath(from: url), "pending/u/1.jpg")
        XCTAssertNil(MomentMediaPath.storageObjectPath(from: "/var/app/moment-media/1.jpg"))
        XCTAssertNil(MomentMediaPath.storageObjectPath(from: nil))
    }

    // MARK: - Validation

    func testValidationRejectsEmptyUnsupportedAndOversizeBeforeUpload() async {
        let storage = SpyMomentMediaStorage()

        await assertUploadThrows(
            .emptyData,
            for: MomentMediaUpload(kind: .photo, data: Data(), contentType: "image/jpeg"),
            storage: storage
        )
        await assertUploadThrows(
            .unsupportedContentType("image/gif"),
            for: MomentMediaUpload(kind: .photo, data: Data([0x1]), contentType: "image/gif"),
            storage: storage
        )
        // A video mime under `.photo` is still unsupported for that kind.
        await assertUploadThrows(
            .unsupportedContentType("video/mp4"),
            for: MomentMediaUpload(kind: .photo, data: Data([0x1]), contentType: "video/mp4"),
            storage: storage
        )

        let oversize = Data(count: MomentMediaStorageConfig.photoMaxBytes + 1)
        await assertUploadThrows(
            .fileTooLarge(
                bytes: oversize.count, limit: MomentMediaStorageConfig.photoMaxBytes
            ),
            for: MomentMediaUpload(kind: .photo, data: oversize, contentType: "image/jpeg"),
            storage: storage
        )

        XCTAssertTrue(storage.uploadedPaths.isEmpty, "validation must precede any Storage write")
    }

    func testValidationAcceptsVideoUpToVideoLimit() throws {
        let upload = MomentMediaUpload(
            kind: .video,
            data: Data(count: MomentMediaStorageConfig.photoMaxBytes + 1),
            contentType: "video/quicktime"
        )
        XCTAssertEqual(try MomentMediaValidator.validate(upload), "mov")
    }

    // MARK: - Mock store upload / delete

    func testLocalStorageWritesMediaAndPosterThenDeletes() async throws {
        let storage = LocalMomentMediaStorage()
        let upload = MomentMediaUpload(
            kind: .video,
            data: Data("movie".utf8),
            contentType: "video/mp4",
            posterJPEGData: Data("poster".utf8)
        )

        let result = try await storage.uploadPending(userID: "user-1", upload: upload)

        XCTAssertEqual(result.kind, .video)
        XCTAssertTrue(result.objectPath.hasPrefix("pending/user-1/"))
        XCTAssertTrue(result.objectPath.hasSuffix(".mp4"))
        XCTAssertEqual(
            result.posterPath, MomentMediaPath.posterObjectPath(for: result.objectPath)
        )
        XCTAssertEqual(result.objectPaths.count, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.publicURL))
        let posterURL = try XCTUnwrap(result.posterURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: posterURL))

        for path in result.objectPaths {
            try await storage.delete(objectPath: path)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.publicURL))
        XCTAssertFalse(FileManager.default.fileExists(atPath: posterURL))

        // Deleting an already-removed key is a no-op, not an error.
        try await storage.delete(objectPath: result.objectPath)
    }

    func testLocalStorageMomentFolderUploadKeepsMomentPrefix() async throws {
        let storage = LocalMomentMediaStorage()
        let momentID = UUID().uuidString
        let result = try await storage.upload(
            momentID: momentID,
            upload: MomentMediaUpload(
                kind: .photo, data: Data("jpeg".utf8), contentType: "image/jpeg"
            )
        )

        XCTAssertTrue(result.objectPath.hasPrefix("\(momentID.lowercased())/"))
        XCTAssertNil(result.posterPath)
        try await storage.delete(objectPath: result.objectPath)
    }

    // MARK: - Orphan rollback

    func testPublishPendingCommitsWithoutRollbackOnSuccess() async throws {
        let storage = SpyMomentMediaStorage()
        var committed: [MomentMediaUploadResult] = []

        try await MomentMediaPublisher.publishPending(
            uploads: [photoUpload(), photoUpload()],
            userID: "user-1",
            storage: storage
        ) { results in
            committed = results
        }

        XCTAssertEqual(committed.count, 2)
        XCTAssertEqual(storage.uploadedPaths.count, 2)
        XCTAssertTrue(storage.deletedPaths.isEmpty)
    }

    func testPublishPendingRollsBackEveryObjectWhenRPCFails() async {
        let storage = SpyMomentMediaStorage()
        let uploads = [
            photoUpload(),
            MomentMediaUpload(
                kind: .video,
                data: Data("movie".utf8),
                contentType: "video/mp4",
                posterJPEGData: Data("poster".utf8)
            )
        ]

        do {
            try await MomentMediaPublisher.publishPending(
                uploads: uploads, userID: "user-1", storage: storage
            ) { _ in
                throw StubRPCError.failed
            }
            XCTFail("expected the simulated RPC failure to propagate")
        } catch {
            XCTAssertEqual(error as? StubRPCError, .failed)
        }

        // Both media objects plus the video poster are removed.
        XCTAssertEqual(storage.uploadedPaths.count, 3)
        XCTAssertEqual(Set(storage.deletedPaths), Set(storage.uploadedPaths))
    }

    func testPublishPendingRollsBackEarlierUploadsWhenALaterUploadFails() async {
        let storage = SpyMomentMediaStorage()
        storage.failUploadAtIndex = 1

        do {
            try await MomentMediaPublisher.publishPending(
                uploads: [photoUpload(), photoUpload()], userID: "user-1", storage: storage
            ) { _ in
                XCTFail("commit must not run when an upload fails")
            }
            XCTFail("expected the upload failure to propagate")
        } catch {
            XCTAssertEqual(error as? StubStorageError, .uploadFailed)
        }

        XCTAssertEqual(storage.deletedPaths, storage.uploadedPaths)
        XCTAssertEqual(storage.uploadedPaths.count, 1)
    }

    func testAppendRollsBackOnlyTheFailingItem() async {
        let storage = SpyMomentMediaStorage()
        let momentID = UUID().uuidString

        // First append commits and must survive the second one's rollback.
        let committed = try? await MomentMediaPublisher.append(
            upload: photoUpload(), momentID: momentID, userID: "user-1", storage: storage
        ) { $0.objectPath }
        XCTAssertNotNil(committed)

        do {
            _ = try await MomentMediaPublisher.append(
                upload: photoUpload(), momentID: momentID, userID: "user-1", storage: storage
            ) { _ in
                throw StubRPCError.failed
            }
            XCTFail("expected the simulated RPC failure to propagate")
        } catch {
            XCTAssertEqual(error as? StubRPCError, .failed)
        }

        XCTAssertEqual(storage.uploadedPaths.count, 2)
        XCTAssertEqual(storage.deletedPaths, [storage.uploadedPaths[1]])
        XCTAssertFalse(storage.deletedPaths.contains(try! XCTUnwrap(committed)))
    }

    func testAppendUsesMomentFolderWhenRequested() async throws {
        let storage = SpyMomentMediaStorage()
        let momentID = UUID().uuidString

        let path = try await MomentMediaPublisher.append(
            upload: photoUpload(),
            momentID: momentID,
            userID: "user-1",
            storage: storage,
            useMomentFolder: true
        ) { $0.objectPath }

        XCTAssertTrue(path.hasPrefix("\(momentID.lowercased())/"))
    }

    // MARK: - Helpers

    private func photoUpload() -> MomentMediaUpload {
        MomentMediaUpload(kind: .photo, data: Data("jpeg".utf8), contentType: "image/jpeg")
    }

    private func assertUploadThrows(
        _ expected: MomentMediaStorageError,
        for upload: MomentMediaUpload,
        storage: SpyMomentMediaStorage,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await storage.uploadPending(userID: "user-1", upload: upload)
            XCTFail("expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? MomentMediaStorageError, expected, file: file, line: line)
        }
    }
}

// MARK: - Doubles

private enum StubRPCError: Error, Equatable { case failed }
private enum StubStorageError: Error, Equatable { case uploadFailed }

/// Records object keys instead of touching Storage or the file system, so
/// rollback assertions read exactly which orphans were cleaned up.
private final class SpyMomentMediaStorage: MomentMediaStoring {
    private(set) var uploadedPaths: [String] = []
    private(set) var deletedPaths: [String] = []
    /// Index (in upload-call order) that should throw instead of uploading.
    var failUploadAtIndex: Int?

    private var uploadCallCount = 0

    func uploadPending(userID: String, upload: MomentMediaUpload) async throws -> MomentMediaUploadResult {
        let fileExtension = try MomentMediaValidator.validate(upload)
        return try record(
            upload,
            at: MomentMediaPath.pendingObjectPath(userID: userID, fileExtension: fileExtension)
        )
    }

    func upload(momentID: String, upload: MomentMediaUpload) async throws -> MomentMediaUploadResult {
        let fileExtension = try MomentMediaValidator.validate(upload)
        return try record(
            upload,
            at: MomentMediaPath.momentObjectPath(momentID: momentID, fileExtension: fileExtension)
        )
    }

    func delete(objectPath: String) async throws {
        deletedPaths.append(objectPath)
    }

    private func record(_ upload: MomentMediaUpload, at objectPath: String) throws -> MomentMediaUploadResult {
        defer { uploadCallCount += 1 }
        if uploadCallCount == failUploadAtIndex { throw StubStorageError.uploadFailed }

        uploadedPaths.append(objectPath)
        var posterPath: String?
        if upload.posterJPEGData?.isEmpty == false {
            let path = MomentMediaPath.posterObjectPath(for: objectPath)
            uploadedPaths.append(path)
            posterPath = path
        }
        return MomentMediaUploadResult(
            kind: upload.kind,
            objectPath: objectPath,
            publicURL: "https://example.invalid/\(objectPath)",
            posterPath: posterPath,
            posterURL: posterPath.map { "https://example.invalid/\($0)" }
        )
    }
}
