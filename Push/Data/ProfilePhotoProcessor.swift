//
//  ProfilePhotoProcessor.swift
//  Push
//
//  On-device resize + JPEG compression before profile photo upload.
//

import UIKit

enum ProfilePhotoProcessor {
    /// Longest edge after downscale — enough for large avatars without multi-MB uploads.
    static let maxDimension: CGFloat = 1024
    static let jpegQuality: CGFloat = 0.82

    /// Returns JPEG bytes suitable for upload, or nil if the image cannot be encoded.
    static func jpegData(from image: UIImage) -> Data? {
        let scaled = scaledImage(image, maxDimension: maxDimension)
        return scaled.jpegData(compressionQuality: jpegQuality)
    }

    /// Decodes picker/library data then compresses. Nil when data is not a usable image.
    static func jpegData(from raw: Data) -> Data? {
        guard let image = UIImage(data: raw) else { return nil }
        return jpegData(from: image)
    }

    static func scaledImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
