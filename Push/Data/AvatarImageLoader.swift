//
//  AvatarImageLoader.swift
//  Push
//
//  Resolves Person.imageAssetPath / profile image strings to UIImage with a
//  small memory cache. Supports bundle assets, local files, and remote HTTPS.
//

import Foundation
import UIKit

enum AvatarImageLoader {
    private static let cache = NSCache<NSString, UIImage>()
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: AvatarImageLimits.memoryCapacity,
            diskCapacity: AvatarImageLimits.diskCapacity
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    /// Synchronous local-only resolve (bundle / file). Remote URLs return nil —
    /// use `image(for:)` for full resolution.
    static func localImage(for path: String?) -> UIImage? {
        guard let path, !path.isEmpty else { return nil }
        if let cached = cache.object(forKey: path as NSString) { return cached }
        if let image = PushImageAssets.image(named: path) {
            cache.setObject(image, forKey: path as NSString)
            return image
        }
        if let image = imageFromFilePath(path) {
            cache.setObject(image, forKey: path as NSString)
            return image
        }
        return nil
    }

    static func image(for path: String?) async -> UIImage? {
        guard let path, !path.isEmpty else { return nil }
        if let cached = cache.object(forKey: path as NSString) { return cached }
        if let local = localImage(for: path) { return local }
        guard let url = remoteURL(from: path) else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }
            guard let image = UIImage(data: data) else { return nil }
            cache.setObject(image, forKey: path as NSString)
            return image
        } catch {
            return nil
        }
    }

    /// Drop a single path (e.g. after the current user replaces their photo).
    static func invalidate(path: String?) {
        guard let path, !path.isEmpty else { return }
        cache.removeObject(forKey: path as NSString)
    }

    static func invalidateAll() {
        cache.removeAllObjects()
    }

    private static func remoteURL(from path: String) -> URL? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        return nil
    }

    private static func imageFromFilePath(_ path: String) -> UIImage? {
        if path.hasPrefix("file://"), let url = URL(string: path) {
            return UIImage(contentsOfFile: url.path)
        }
        if path.hasPrefix("/") {
            return UIImage(contentsOfFile: path)
        }
        return nil
    }
}

private enum AvatarImageLimits {
    static let memoryCapacity = 8 * 1024 * 1024
    static let diskCapacity = 32 * 1024 * 1024
}
