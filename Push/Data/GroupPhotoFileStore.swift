//
//  GroupPhotoFileStore.swift
//  Push
//
//  Mock-mode on-disk home for a group's JPEG (mirrors ProfilePhotoFileStore).
//

import Foundation

enum GroupPhotoFileStore {
    private static let folderName = "group-photos"

    static func fileURL(groupID: String) throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = root.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = groupID.replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent("\(safe).jpg", isDirectory: false)
    }

    @discardableResult
    static func save(groupID: String, jpegData: Data) throws -> URL {
        let url = try fileURL(groupID: groupID)
        try jpegData.write(to: url, options: .atomic)
        return url
    }

    static func remove(groupID: String) {
        guard let url = try? fileURL(groupID: groupID) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
