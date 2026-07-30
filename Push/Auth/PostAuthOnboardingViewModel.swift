// Push/Auth/PostAuthOnboardingViewModel.swift
import Foundation
import UserNotifications

/// Screens after a live session is prepared (new accounts only).
/// Approach 2 spine: value → location → teach → optional graph → done.
enum PostAuthOnboardingScreen: Equatable {
    case value
    case locationPrimer
    case locationBlocked
    case ghost
    case coordinate
    case notifications
    case contacts
    case findPeople
    case done

    var showsBackButton: Bool {
        switch self {
        case .value, .locationBlocked, .done:
            return false
        case .locationPrimer, .ghost, .coordinate, .notifications, .contacts, .findPeople:
            return true
        }
    }

    /// 1-based progress across happy-path steps (value → findPeople). Blocked reuses location step.
    var progressStep: Int {
        switch self {
        case .value: return 1
        case .locationPrimer, .locationBlocked: return 2
        case .ghost: return 3
        case .coordinate: return 4
        case .notifications: return 5
        case .contacts: return 6
        case .findPeople: return 7
        case .done: return 0
        }
    }

    static let progressTotal = 7
}

/// One discoverable person on the find-people step.
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
    @Published private(set) var screen: PostAuthOnboardingScreen = .value
    @Published private(set) var people: [OnboardingDiscoverPerson] = []
    @Published private(set) var addedIDs: Set<Person.ID> = []
    @Published private(set) var actingIDs: Set<Person.ID> = []
    @Published private(set) var isBusy = false
    @Published private(set) var isLoadingPeople = false
    @Published var errorMessage: String?
    @Published private(set) var isFinished = false

    private let container: AppDataContainer
    private let notificationCenter: UNUserNotificationCenter
    /// Injected for tests; falls back to the container session (may be nil pre-install).
    private let locationSession: LocationSessioning?

    private enum Limit {
        static let discoverCount = 20
    }

    private enum Copy {
        static let defaultsFailed = "Couldn't save sharing defaults. Check your connection and try again."
        static let friendsLoadFailed = "Couldn't load people right now. You can skip and add friends later."
        static let friendRequestFailed = "Couldn't send that request. Try again."
        static let completeFailed = "Couldn't finish setup. Check your connection and try again."
        static let locationRequired = "Location access is required to finish setup. Enable location and try again."
    }

    init(
        container: AppDataContainer? = nil,
        notificationCenter: UNUserNotificationCenter = .current(),
        locationSession: LocationSessioning? = nil
    ) {
        let resolved = container ?? .shared
        self.container = resolved
        self.notificationCenter = notificationCenter
        self.locationSession = locationSession ?? resolved.locationSession
    }

    var findPeopleCTALabel: String {
        let count = addedIDs.count
        guard count > 0 else { return "Continue" }
        return "Continue with \(count) friend\(count == 1 ? "" : "s")"
    }

    /// Alias kept for screens still wiring the friends CTA label.
    var friendsCTALabel: String { findPeopleCTALabel }

    func goBack() {
        errorMessage = nil
        switch screen {
        case .locationPrimer:
            screen = .value
        case .ghost:
            screen = .locationPrimer
        case .coordinate:
            screen = .ghost
        case .notifications:
            screen = .coordinate
        case .contacts:
            screen = .notifications
        case .findPeople:
            screen = .contacts
        case .value, .locationBlocked, .done:
            break
        }
    }

    // MARK: - Value → location primer

    func continueFromValue() {
        errorMessage = nil
        screen = .locationPrimer
    }

    // MARK: - Location

    func enableLocation() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        await locationSession?.startIfEligible()
        guard hasRequiredLocationAuthorization else {
            screen = .locationBlocked
            return
        }
        await applyDefaultsAndAdvanceToGhost()
    }

    /// Re-check after Settings (blocked recovery). Advances only when authorized.
    func retryLocationAccess() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        await locationSession?.startIfEligible()
        guard hasRequiredLocationAuthorization else {
            screen = .locationBlocked
            return
        }
        await applyDefaultsAndAdvanceToGhost()
    }

    // MARK: - Teach steps

    func continueFromGhost() {
        errorMessage = nil
        screen = .coordinate
    }

    func continueFromCoordinate() {
        errorMessage = nil
        screen = .notifications
    }

    // MARK: - Notifications → contacts

    func enableNotifications() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        _ = try? await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
        screen = .contacts
    }

    func skipNotifications() async {
        errorMessage = nil
        screen = .contacts
    }

    // MARK: - Contacts → find people

    /// Contacts matching lands in a later task; advance immediately for now.
    func skipContacts() async {
        errorMessage = nil
        await loadPeopleAndAdvance()
    }

    func continueFromContacts() async {
        await skipContacts()
    }

    // MARK: - Find people

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

    func continueFromFindPeople() async {
        await finishOnboarding()
    }

    func openApp() {
        isFinished = true
    }

    // MARK: - Private

    private func applyDefaultsAndAdvanceToGhost() async {
        do {
            try await applyDefaultSharingAndPublishing()
            screen = .ghost
        } catch {
            errorMessage = Copy.defaultsFailed
            // Stay on primer (or blocked if we arrived via retry) so the user can retry the write.
            if screen != .locationBlocked {
                screen = .locationPrimer
            }
        }
    }

    private func applyDefaultSharingAndPublishing() async throws {
        try await container.sharing.setGlobalDefaults(
            location: .exact,
            activity: .full,
            availability: .full
        )
        await locationSession?.setPresencePublishingEnabled(true)
        try await mirrorExactActivityPrivacyToggles()
    }

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
        screen = .findPeople
    }

    /// Completion requires when-in-use (or always) location authorization — fail closed.
    private var hasRequiredLocationAuthorization: Bool {
        locationSession?.state.authorization.allowsWhenInUseUpdates == true
    }

    private func finishOnboarding() async {
        guard !isBusy else { return }
        guard hasRequiredLocationAuthorization else {
            errorMessage = Copy.locationRequired
            return
        }
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

    /// Align Profile toggles with exact location + activity (post-allow defaults).
    private func mirrorExactActivityPrivacyToggles() async throws {
        let profile = try await container.profile.userProfile()
        var activity = profile.activityVisibility
        var map = profile.mapPreferences
        let close = profile.closeFriends

        func setToggle(_ items: inout [ProfileToggleItem], id: String, enabled: Bool) {
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            items[index].isEnabled = enabled
        }

        setToggle(&activity, id: "place", enabled: true)
        setToggle(&activity, id: "activity", enabled: true)
        setToggle(&map, id: "soft-place", enabled: false)

        try await container.profile.updatePrivacy(
            activityVisibility: activity,
            mapPreferences: map,
            closeFriends: close
        )
    }
}
