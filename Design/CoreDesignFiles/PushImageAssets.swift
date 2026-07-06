//
//  PushImageAssets.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import UIKit

enum PushImageAssets {
    static func image(named assetName: String?) -> UIImage? {
        guard let assetName, !assetName.isEmpty else {
            return nil
        }

        if let image = UIImage(named: assetName) {
            return image
        }

        if let image = imageFromBundledPath(assetName) {
            return image
        }

        let fileName = assetName as NSString
        let resourceName = fileName.deletingPathExtension
        let resourceExtension = fileName.pathExtension
        guard !resourceName.isEmpty, !resourceExtension.isEmpty,
              let path = Bundle.main.path(forResource: resourceName, ofType: resourceExtension) else {
            return nil
        }

        return UIImage(contentsOfFile: path)
    }

    private static func imageFromBundledPath(_ assetName: String) -> UIImage? {
        let fileName = assetName as NSString
        let resourceName = fileName.lastPathComponent
        let resourceDirectory = fileName.deletingLastPathComponent
        let resourceBaseName = (resourceName as NSString).deletingPathExtension
        let resourceExtension = (resourceName as NSString).pathExtension

        guard !resourceDirectory.isEmpty,
              !resourceBaseName.isEmpty,
              !resourceExtension.isEmpty,
              let path = Bundle.main.path(
                forResource: resourceBaseName,
                ofType: resourceExtension,
                inDirectory: resourceDirectory
              ) else {
            return nil
        }

        return UIImage(contentsOfFile: path)
    }
}
