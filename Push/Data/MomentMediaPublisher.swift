//
//  MomentMediaPublisher.swift
//  Push
//
//  The upload → RPC → rollback sequence for Moment media. Storage has no
//  transaction with Postgres, so every mutation that attaches an object must
//  delete that object again when the RPC fails, or the bucket keeps orphans.
//  Same pattern as SupabaseProfileRepository / SupabaseGroupRepository photo
//  writes, generalized because Moments upload batches.
//
//  Repository slices (S4+) call these instead of touching `MomentMediaStoring`
//  directly, so rollback can never be forgotten at a call site.
//

import Foundation

enum MomentMediaPublisher {
    /// Publish path: upload every item to the caller's pending prefix, then run
    /// `commit` (`create_moment`). All-or-nothing — a failed upload or a failed
    /// commit rolls back every object this call created, then rethrows.
    static func publishPending<T>(
        uploads: [MomentMediaUpload],
        userID: String,
        storage: MomentMediaStoring,
        commit: ([MomentMediaUploadResult]) async throws -> T
    ) async throws -> T {
        var uploaded: [MomentMediaUploadResult] = []
        do {
            for upload in uploads {
                uploaded.append(
                    try await storage.uploadPending(userID: userID, upload: upload)
                )
            }
            return try await commit(uploaded)
        } catch {
            await rollback(uploaded, storage: storage)
            throw error
        }
    }

    /// Append path ("Add yours"): one object, one `append_moment_media` call.
    /// Per-item on purpose — a multi-select append keeps the items whose RPC
    /// already committed and only rolls back the failing one.
    static func append<T>(
        upload: MomentMediaUpload,
        momentID: String,
        userID: String,
        storage: MomentMediaStoring,
        useMomentFolder: Bool = false,
        commit: (MomentMediaUploadResult) async throws -> T
    ) async throws -> T {
        let result = useMomentFolder
            ? try await storage.upload(momentID: momentID, upload: upload)
            : try await storage.uploadPending(userID: userID, upload: upload)
        do {
            return try await commit(result)
        } catch {
            await rollback([result], storage: storage)
            throw error
        }
    }

    /// Best-effort orphan cleanup. Never throws: the caller is already failing
    /// and a leftover object is less bad than masking the original error.
    static func rollback(_ results: [MomentMediaUploadResult], storage: MomentMediaStoring) async {
        for objectPath in results.flatMap(\.objectPaths) {
            try? await storage.delete(objectPath: objectPath)
        }
    }
}
