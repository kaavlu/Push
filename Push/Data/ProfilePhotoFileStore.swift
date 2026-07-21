//
//  ProfilePhotoFileStore.swift
//  Push
//
//  Mock-mode on-disk home for the current user's profile JPEG.
//

import Foundation

enum ProfilePhotoFileStore {
    private static let folderName = "profile-photos"

    static func fileURL(userID: String) throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = root.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Opaque id as file name — avoids path separators from any future id scheme.
        let safe = userID.replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent("\(safe).jpg", isDirectory: false)
    }

    @discardableResult
    static func save(userID: String, jpegData: Data) throws -> URL {
        let url = try fileURL(userID: userID)
        try jpegData.write(to: url, options: .atomic)
        return url
    }

    static func remove(userID: String) {
        guard let url = try? fileURL(userID: userID) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
