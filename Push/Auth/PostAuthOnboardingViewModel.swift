// Push/Auth/PostAuthOnboardingViewModel.swift
import Foundation
import UserNotifications

/// Screens after a live session is prepared (new accounts only).
enum PostAuthOnboardingScreen: Equatable {
    case privacy
    case location
    case notifications
    case friends
    case done

    var showsBackButton: Bool {
        switch self {
        case .privacy, .done: return false
        case .location, .notifications, .friends: return true
        }
    }

    /// 1-based progress across setup steps (privacy → friends).
    var progressStep: Int {
        switch self {
        case .privacy: return 1
        case .location: return 2
        case .notifications: return 3
        case .friends, .done: return 4
        }
    }

    static let progressTotal = 4
}

/// One discoverable person on the find-friends step.
struct OnboardingDiscoverPerson: Identifiable, Equatable {
    let result: PersonSearchResult
    var id: Person.ID { result.id }
    var name: String { result.person.firstName }
    var handle: String { result.handle }
    var imageAssetPath: String? { result.person.imageAssetPath }
    var relation: FriendshipRelation { result.relation }
}

@MainActor
final class PostAuthOnboardingViewModel: ObservableObject {
    @Published private(set) var screen: PostAuthOnboardingScreen = .privacy
    @Published private(set) var privacy: OnboardingPrivacyOption = .exactActivity
    @Published private(set) var people: [OnboardingDiscoverPerson] = []
    @Published private(set) var addedIDs: Set<Person.ID> = []
    @Published private(set) var actingIDs: Set<Person.ID> = []
    @Published private(set) var isBusy = false
    @Published private(set) var isLoadingPeople = false
    @Published var errorMessage: String?
    @Published private(set) var isFinished = false

    private let container: AppDataContainer
    private let notificationCenter: UNUserNotificationCenter

    private enum Limit {
        static let discoverCount = 20
    }

    private enum Copy {
        static let privacyFailed = "Couldn't save privacy. Check your connection and try again."
        static let friendsLoadFailed = "Couldn't load people right now. You can skip and add friends later."
        static let friendRequestFailed = "Couldn't send that request. Try again."
        static let completeFailed = "Couldn't finish setup. Check your connection and try again."
    }

    init(
        container: AppDataContainer? = nil,
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.container = container ?? .shared
        self.notificationCenter = notificationCenter
    }

    var privacyTitle: String { privacy.title }

    var friendsCTALabel: String {
        let count = addedIDs.count
        guard count > 0 else { return "Continue" }
        return "Continue with \(count) friend\(count == 1 ? "" : "s")"
    }

    func select(_ option: OnboardingPrivacyOption) {
        privacy = option
    }

    func goBack() {
        errorMessage = nil
        switch screen {
        case .location: screen = .privacy
        case .notifications: screen = .location
        case .friends: screen = .notifications
        case .privacy, .done: break
        }
    }

    // MARK: - Privacy → location

    func continueFromPrivacy() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await container.sharing.setGlobalDefaults(
                location: privacy.locationVisibility,
                activity: privacy.activityVisibility,
                availability: privacy.availabilityVisibility
            )
            await container.locationSession?.setPresencePublishingEnabled(
                privacy.isPresencePublishingEnabled
            )
            try await mirrorPrivacyToggles()
            screen = .location
        } catch {
            errorMessage = Copy.privacyFailed
        }
    }

    // MARK: - Location → notifications

    func enableLocation() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        await container.locationSession?.startIfEligible()
        screen = .notifications
    }

    func skipLocation() {
        errorMessage = nil
        screen = .notifications
    }

    // MARK: - Notifications → friends

    func enableNotifications() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        _ = try? await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        await loadPeopleAndAdvance()
    }

    func skipNotifications() async {
        errorMessage = nil
        await loadPeopleAndAdvance()
    }

    // MARK: - Friends

    func toggleFriend(_ id: Person.ID) async {
        if addedIDs.contains(id) {
            // Already requested this session — leave pending; no cancel UX on this step.
            return
        }
        guard actingIDs.insert(id).inserted else { return }
        defer { actingIDs.remove(id) }
        errorMessage = nil
        do {
            _ = try await container.friends.sendFriendRequest(to: id)
            addedIDs.insert(id)
            if let index = people.firstIndex(where: { $0.id == id }) {
                var person = people[index]
                let requestID = "pending-\(id)"
                people[index] = OnboardingDiscoverPerson(
                    result: PersonSearchResult(
                        person: person.result.person,
                        handle: person.handle,
                        relation: .outgoingPending(requestID: requestID)
                    )
                )
            }
        } catch {
            errorMessage = Copy.friendRequestFailed
        }
    }

    func isAdded(_ id: Person.ID) -> Bool {
        addedIDs.contains(id) || {
            if case .outgoingPending = people.first(where: { $0.id == id })?.relation {
                return true
            }
            return false
        }()
    }

    func continueFromFriends() async {
        await finishOnboarding()
    }

    func openApp() {
        isFinished = true
    }

    // MARK: - Private

    private func loadPeopleAndAdvance() async {
        isLoadingPeople = true
        errorMessage = nil
        defer { isLoadingPeople = false }
        do {
            let hits = try await container.friends.discoverPeople(limit: Limit.discoverCount)
            people = hits.map { OnboardingDiscoverPerson(result: $0) }
        } catch {
            people = []
            errorMessage = Copy.friendsLoadFailed
        }
        screen = .friends
    }

    private func finishOnboarding() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await container.profile.completeOnboarding()
            screen = .done
        } catch {
            errorMessage = Copy.completeFailed
        }
    }

    /// Keep Profile settings toggles roughly aligned with the chosen mode.
    private func mirrorPrivacyToggles() async throws {
        let profile = try await container.profile.userProfile()
        var activity = profile.activityVisibility
        var map = profile.mapPreferences
        let close = profile.closeFriends

        func setToggle(_ items: inout [ProfileToggleItem], id: String, enabled: Bool) {
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            items[index].isEnabled = enabled
        }

        switch privacy {
        case .exactActivity:
            setToggle(&activity, id: "place", enabled: true)
            setToggle(&activity, id: "activity", enabled: true)
            setToggle(&map, id: "soft-place", enabled: false)
        case .exact:
            setToggle(&activity, id: "place", enabled: true)
            setToggle(&activity, id: "activity", enabled: false)
            setToggle(&map, id: "soft-place", enabled: false)
        case .vague:
            setToggle(&activity, id: "place", enabled: true)
            setToggle(&activity, id: "activity", enabled: true)
            setToggle(&map, id: "soft-place", enabled: true)
        case .ghost:
            setToggle(&activity, id: "place", enabled: false)
            setToggle(&activity, id: "activity", enabled: false)
            setToggle(&map, id: "soft-place", enabled: true)
        }

        try await container.profile.updatePrivacy(
            activityVisibility: activity,
            mapPreferences: map,
            closeFriends: close
        )
    }
}
