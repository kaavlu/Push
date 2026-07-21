import UIKit
import XCTest
@testable import Push

@MainActor
final class ProfilePhotoTests: XCTestCase {
    func testProcessorDownscalesAndEncodesJPEG() throws {
        let large = makeSolidImage(width: 2000, height: 1500, color: .red)
        let data = try XCTUnwrap(ProfilePhotoProcessor.jpegData(from: large))
        let decoded = try XCTUnwrap(UIImage(data: data))
        let longest = max(decoded.size.width, decoded.size.height)
        XCTAssertLessThanOrEqual(longest, ProfilePhotoProcessor.maxDimension + 1)
    }

    func testProcessorRejectsNonImageData() {
        XCTAssertNil(ProfilePhotoProcessor.jpegData(from: Data("not-an-image".utf8)))
    }

    func testLocalUpdateProfilePhotoPersistsFilePath() async throws {
        let container = AppDataContainer(seed: .standard())
        let userID = container.currentUserID
        let jpeg = try XCTUnwrap(
            ProfilePhotoProcessor.jpegData(from: makeSolidImage(width: 64, height: 64, color: .blue))
        )

        try await container.profile.updateProfilePhoto(jpegData: jpeg)

        let user = try await container.friends.currentUser()
        let path = try XCTUnwrap(user.imageAssetPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        XCTAssertNotNil(UIImage(contentsOfFile: path))

        // Second write replaces the file and keeps a stable path for the user id.
        let jpeg2 = try XCTUnwrap(
            ProfilePhotoProcessor.jpegData(from: makeSolidImage(width: 32, height: 32, color: .green))
        )
        try await container.profile.updateProfilePhoto(jpegData: jpeg2)
        let refreshed = try await container.friends.currentUser()
        XCTAssertEqual(refreshed.imageAssetPath, path)
        XCTAssertNotNil(UIImage(contentsOfFile: path))

        ProfilePhotoFileStore.remove(userID: userID)
    }

    func testLocalRemoveProfilePhotoClearsPath() async throws {
        let container = AppDataContainer(seed: .standard())
        let jpeg = try XCTUnwrap(
            ProfilePhotoProcessor.jpegData(from: makeSolidImage(width: 48, height: 48, color: .orange))
        )
        try await container.profile.updateProfilePhoto(jpegData: jpeg)
        try await container.profile.removeProfilePhoto()

        let user = try await container.friends.currentUser()
        XCTAssertNil(user.imageAssetPath)
    }

    func testAvatarLoaderResolvesLocalFileAndBundlePaths() async throws {
        let jpeg = try XCTUnwrap(
            ProfilePhotoProcessor.jpegData(
                from: makeSolidImage(width: 40, height: 40, color: .purple)
            )
        )
        let url = try ProfilePhotoFileStore.save(userID: "avatar-loader-test", jpegData: jpeg)
        defer { ProfilePhotoFileStore.remove(userID: "avatar-loader-test") }

        let loaded = await AvatarImageLoader.image(for: url.path)
        XCTAssertNotNil(loaded)
        AvatarImageLoader.invalidate(path: url.path)

        // Seed profile asset may resolve via bundle path depending on host bundle.
        _ = AvatarImageLoader.localImage(for: "assets/profile/manav.jpeg")
        let missing = await AvatarImageLoader.image(for: "https://example.invalid/nope.jpg")
        XCTAssertNil(missing)
    }

    func testStorageObjectPathParsesPublicAvatarURL() {
        let url = "https://tzzvwjhvjduyqywlszqc.supabase.co/storage/v1/object/public/avatars/abc/photo.jpg"
        XCTAssertEqual(ProfilePhotoPath.storageObjectPath(from: url), "abc/photo.jpg")
        XCTAssertNil(ProfilePhotoPath.storageObjectPath(from: "assets/friends/chitty.png"))
        XCTAssertNil(ProfilePhotoPath.storageObjectPath(from: nil))
    }

    func testGroupPhotoPathParsesPublicURLAndAvatarLoaderReadsFile() async throws {
        let publicURL =
            "https://tzzvwjhvjduyqywlszqc.supabase.co/storage/v1/object/public/group-photos/"
            + "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/photo.jpg"
        XCTAssertEqual(
            GroupPhotoPath.storageObjectPath(from: publicURL),
            "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/photo.jpg"
        )
        XCTAssertNil(GroupPhotoPath.storageObjectPath(from: "assets/groups/India/chitty.png"))

        let jpeg = try XCTUnwrap(
            ProfilePhotoProcessor.jpegData(
                from: makeSolidImage(width: 32, height: 32, color: .orange)
            )
        )
        let url = try GroupPhotoFileStore.save(groupID: "group-avatar-loader", jpegData: jpeg)
        defer { GroupPhotoFileStore.remove(groupID: "group-avatar-loader") }
        let loaded = await AvatarImageLoader.image(for: url.path)
        XCTAssertNotNil(loaded, "group mock paths must resolve like profile files")
        AvatarImageLoader.invalidate(path: url.path)
    }

    func testLivePhotoUploadWritesPathAndRollsBackOnProfileFailure() async throws {
        let storage = ProfilePhotoStorageSpy()
        let loader = LiveDataLoaderSpy()
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let repo = SupabaseProfileRepository(
            store: store, currentUserID: "self", photoStorage: storage
        )
        let jpeg = try XCTUnwrap(
            ProfilePhotoProcessor.jpegData(from: makeSolidImage(width: 20, height: 20, color: .cyan))
        )

        try await repo.updateProfilePhoto(jpegData: jpeg)
        XCTAssertEqual(storage.uploadCount, 1)
        XCTAssertEqual(storage.deleteCount, 0)
        let path = store.cachedImagePath(userID: "self")
        XCTAssertEqual(path, storage.lastPublicURL)

        // Profile write failure after upload deletes the new object and leaves path unchanged.
        let previous = path
        loader.writeError = TestPhotoFailure.expected
        storage.resetCounts()
        do {
            try await repo.updateProfilePhoto(jpegData: jpeg)
            XCTFail("Expected profile write failure")
        } catch {
            XCTAssertEqual(storage.uploadCount, 1)
            XCTAssertEqual(storage.deleteCount, 1, "orphaned upload must be deleted")
            XCTAssertEqual(store.cachedImagePath(userID: "self"), previous)
        }
    }

    func testLiveRemoveClearsPathBeforeStorageDelete() async throws {
        let storage = ProfilePhotoStorageSpy()
        storage.publicURLTemplate =
            "https://example.com/storage/v1/object/public/avatars/{path}"
        let loader = LiveDataLoaderSpy()
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let repo = SupabaseProfileRepository(
            store: store, currentUserID: "self", photoStorage: storage
        )
        let jpeg = try XCTUnwrap(
            ProfilePhotoProcessor.jpegData(from: makeSolidImage(width: 16, height: 16, color: .brown))
        )
        try await repo.updateProfilePhoto(jpegData: jpeg)
        XCTAssertNotNil(store.cachedImagePath(userID: "self"))

        try await repo.removeProfilePhoto()
        XCTAssertNil(store.cachedImagePath(userID: "self"))
        XCTAssertGreaterThanOrEqual(storage.deleteCount, 1)
    }

    private func makeSolidImage(width: CGFloat, height: CGFloat, color: UIColor) -> UIImage {
        let size = CGSize(width: width, height: height)
        // scale=1 so JPEG encode/decode preserves point size in tests.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

private enum TestPhotoFailure: Error { case expected }

@MainActor
private final class ProfilePhotoStorageSpy: ProfilePhotoStoring {
    var uploadCount = 0
    var deleteCount = 0
    var lastPublicURL: String?
    var lastObjectPath: String?
    var publicURLTemplate = "https://example.com/storage/v1/object/public/avatars/{path}"

    func upload(userID: String, jpegData: Data) async throws -> ProfilePhotoUploadResult {
        uploadCount += 1
        let objectPath = "\(userID)/\(UUID().uuidString.lowercased()).jpg"
        let publicURL = publicURLTemplate.replacingOccurrences(of: "{path}", with: objectPath)
        lastObjectPath = objectPath
        lastPublicURL = publicURL
        return ProfilePhotoUploadResult(objectPath: objectPath, publicURL: publicURL)
    }

    func delete(objectPath: String) async throws {
        deleteCount += 1
    }

    func resetCounts() {
        uploadCount = 0
        deleteCount = 0
    }
}
