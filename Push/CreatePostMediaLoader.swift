//
//  CreatePostMediaLoader.swift
//  Push
//
//  Photos picker → publishable draft item. Photos are re-encoded to JPEG (the
//  same compress step profile/group photos use) so the bytes always match an
//  accepted `moment-media` content type; videos keep their container and ship
//  without a poster, which `create_moment` accepts.
//

import Foundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum CreatePostMediaLoader {

    /// Nil when the item can't be decoded, isn't a supported container, or is
    /// over the client cap — the picked item is then silently skipped, exactly
    /// like the previous local-only loader did for undecodable images.
    static func draft(from item: PhotosPickerItem) async -> AddYoursDraftItem? {
        guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else {
            return nil
        }
        if let contentType = videoContentType(for: item) {
            return videoDraft(data: data, contentType: contentType)
        }
        return photoDraft(data: data)
    }

    /// Test/preview seam: builds the same draft shape from raw bytes.
    static func photoDraft(data: Data) -> AddYoursDraftItem? {
        guard let image = UIImage(data: data),
              let jpeg = ProfilePhotoProcessor.jpegData(from: image)
        else { return nil }
        let upload = MomentMediaUpload(
            kind: .photo,
            data: jpeg,
            contentType: MomentMediaStorageConfig.jpegContentType
        )
        guard (try? MomentMediaValidator.validate(upload)) != nil else { return nil }
        return AddYoursDraftItem(kind: .photo, previewImage: image, upload: upload)
    }

    private static func videoDraft(data: Data, contentType: String) -> AddYoursDraftItem? {
        let upload = MomentMediaUpload(kind: .video, data: data, contentType: contentType)
        guard (try? MomentMediaValidator.validate(upload)) != nil else { return nil }
        // Poster frames are a later slice; the RPC accepts a null poster.
        return AddYoursDraftItem(kind: .video, previewImage: nil, upload: upload)
    }

    /// Nil means "treat as a photo". Only the two container types the bucket
    /// accepts are recognized; anything else falls through to the photo path
    /// and is dropped there.
    private static func videoContentType(for item: PhotosPickerItem) -> String? {
        let types = item.supportedContentTypes
        if types.contains(where: { $0.conforms(to: .mpeg4Movie) }) {
            return MomentMediaStorageConfig.mp4ContentType
        }
        if types.contains(where: { $0.conforms(to: .quickTimeMovie) }) {
            return MomentMediaStorageConfig.quickTimeContentType
        }
        if types.contains(where: { $0.conforms(to: .movie) || $0.conforms(to: .video) }) {
            return MomentMediaStorageConfig.quickTimeContentType
        }
        return nil
    }
}
