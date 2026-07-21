//
//  StartPushModels.swift
//  Push
//
//  Created by Manav Khanvilkar on 7/1/26.
//

import Foundation


struct PushRecipientItem: Identifiable, Equatable {
    let id: String
    let name: String
    let memberCount: Int?
    let imageAssetName: String?
    let initials: String
    let isGroup: Bool
}

struct StartPushLaunchContext: Identifiable, Equatable {
    let id = UUID()
    let recipientIDs: Set<String>
    let locationHint: String?
    let initialStep: Int
    let editPlanID: PushPlan.ID?
    let editRecipientIDs: Set<String>
    let editTitle: String?
    let editNote: String?

    static let blank = StartPushLaunchContext(
        recipientIDs: [],
        locationHint: nil,
        initialStep: StartPushStep.recipients,
        editPlanID: nil,
        editRecipientIDs: [],
        editTitle: nil,
        editNote: nil
    )

    static func friends(_ friendIDs: [String], locationHint: String? = nil) -> StartPushLaunchContext {
        let recipientIDs = Set(friendIDs.map { "friend_\($0)" })
        return StartPushLaunchContext(
            recipientIDs: recipientIDs,
            locationHint: locationHint,
            initialStep: recipientIDs.isEmpty ? StartPushStep.recipients : StartPushStep.details,
            editPlanID: nil,
            editRecipientIDs: [],
            editTitle: nil,
            editNote: nil
        )
    }

    static func group(_ groupID: String, locationHint: String? = nil) -> StartPushLaunchContext {
        return StartPushLaunchContext(
            recipientIDs: ["group_\(groupID)"],
            locationHint: locationHint,
            initialStep: StartPushStep.details,
            editPlanID: nil,
            editRecipientIDs: [],
            editTitle: nil,
            editNote: nil
        )
    }

    static func edit(planID: PushPlan.ID) -> StartPushLaunchContext {
        StartPushLaunchContext(
            recipientIDs: [],
            locationHint: nil,
            initialStep: StartPushStep.recipients,
            editPlanID: planID,
            editRecipientIDs: [],
            editTitle: nil,
            editNote: nil
        )
    }

    static func edit(plan: PlanData) -> StartPushLaunchContext {
        let recipientIDs = Set(plan.participants.map { "friend_\($0.id)" })
        return StartPushLaunchContext(
            recipientIDs: recipientIDs,
            locationHint: plan.locationHint,
            initialStep: StartPushStep.recipients,
            editPlanID: plan.id,
            editRecipientIDs: recipientIDs,
            editTitle: plan.title,
            editNote: plan.note
        )
    }

    static func from(puck: MapPuckData) -> StartPushLaunchContext {
        if puck.kind == .friendGroup, let groupID = groupID(from: puck.people.first?.id) {
            return .group(groupID, locationHint: locationHint(from: puck))
        }
        let friendIDs = puck.people
            .filter { !$0.isCurrentUser && groupID(from: $0.id) == nil }
            .map(\.id)
        return .friends(friendIDs, locationHint: locationHint(from: puck))
    }

    private static func groupID(from id: String?) -> String? {
        guard let id, id.hasPrefix("group-") else { return nil }
        return String(id.dropFirst("group-".count))
    }

    private static func locationHint(from puck: MapPuckData) -> String? {
        puck.people.first?.placeName ?? puck.people.first?.activityDisplayText
    }
}

enum StartPushStep {
    static let recipients = 1
    static let details = 2
    static let timing = 3
    static let confirmation = 4
}

let pushSuggestions = ["Coffee run", "Taco night", "Sunset walk", "Hit the gym", "Dessert run", "Game night"]

private let pushTextMaxLength = 120

@MainActor
final class StartPushViewModel: ObservableObject {
    @Published var step: Int = 1
    @Published var selectedRecipientIDs: Set<String> = []
    @Published var pushText: String = "" {
        didSet {
            if pushText.count > pushTextMaxLength {
                pushText = String(pushText.prefix(pushTextMaxLength))
            }
        }
    }
    @Published var selectedTime: Date = Date()
    @Published var location: String = ""
    @Published var notes: String = ""
    @Published var searchText: String = ""

    @Published private(set) var groups: [PushRecipientItem] = []
    @Published private(set) var friends: [PushRecipientItem] = []
    @Published private(set) var likelyFreeNow: [PushRecipientItem] = []
    @Published private(set) var mightBeInterested: [PushRecipientItem] = []
    @Published private(set) var loadState: LoadState<Void> = .idle

    private let container: AppDataContainer?
    private let launchContext: StartPushLaunchContext
    // Prevents duplicate submissions if the user somehow triggers the flow twice.
    private var hasSubmitted = false
    // The push behind this screen, if one already exists in Supabase: either
    // the plan being edited, or the one just created by `submit()`. Nil for
    // a brand-new draft that hasn't been submitted yet, so the trash button
    // has nothing to delete.
    @Published private(set) var persistedPushID: PushPlan.ID?

    var canAdvanceStep1: Bool { !selectedRecipientIDs.isEmpty }
    var canAdvanceStep2: Bool { !pushText.trimmingCharacters(in: .whitespaces).isEmpty }
    var characterCount: Int { pushText.count }
    var pushTextMaxCount: Int { pushTextMaxLength }
    var isEditMode: Bool { launchContext.editPlanID != nil }
    var submitButtonTitle: String { isEditMode ? "Save changes" : "Start push" }
    var canDeletePush: Bool { persistedPushID != nil }

    /// True when the graph has at least one friend or group to invite.
    var hasInviteesAvailable: Bool { !friends.isEmpty || !groups.isEmpty }

    /// Step-1 presentation: empty only when load succeeded with no friends and no groups.
    /// Search no-match keeps `.content` (filtered lists may be empty).
    var surfacePhase: SurfaceContentPhase {
        switch loadState {
        case .idle, .loading:
            return loadState.value == nil ? .loading : phaseForLoadedRecipients()
        case .failed:
            return loadState.value == nil ? .failed : phaseForLoadedRecipients()
        case .loaded:
            return phaseForLoadedRecipients()
        }
    }

    private func phaseForLoadedRecipients() -> SurfaceContentPhase {
        hasInviteesAvailable ? .content : .empty
    }

    var selectedRecipients: [PushRecipientItem] {
        (groups + friends).filter { selectedRecipientIDs.contains($0.id) }
    }

    var filteredFriends: [PushRecipientItem] {
        guard !searchText.isEmpty else { return friends }
        return friends.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredGroups: [PushRecipientItem] {
        guard !searchText.isEmpty else { return groups }
        return groups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var primaryRecipientLabel: String {
        guard let first = selectedRecipients.first else { return "" }
        let extra = selectedRecipients.count - 1
        return extra == 0 ? first.name : "\(first.name) +\(extra)"
    }

    // `container` defaults via `?? .shared` (not `= .shared`) because default-argument
    // expressions are checked in a nonisolated context even inside a @MainActor
    // initializer; `.shared` is a MainActor-isolated mutable static, so the fallback
    // must live in the (MainActor) initializer body instead.
    init(container: AppDataContainer? = nil, context: StartPushLaunchContext? = nil) {
        self.container = container ?? .shared
        self.launchContext = context ?? .blank
        applyLaunchContext()
        Task { await load() }
    }

    private func applyLaunchContext() {
        selectedRecipientIDs = launchContext.recipientIDs
        if let editTitle = launchContext.editTitle {
            pushText = editTitle
        }
        if let locationHint = launchContext.locationHint {
            location = locationHint
        }
        if let editNote = launchContext.editNote {
            notes = editNote
        }
        step = launchContext.initialStep
        persistedPushID = launchContext.editPlanID
    }

    func load() async {
        guard let container else { return }
        if loadState.value == nil { loadState = .loading }
        do {
            let groupList = try await container.groups.groups()
            let memberships = try await container.groups.memberships()
            let friendList = try await container.friends.friends()
            let statuses = try await container.friends.presenceStatuses()

            let statusByPersonID = Dictionary(uniqueKeysWithValues: statuses.map { ($0.personID, $0) })
            let memberCountByGroup: [String: Int] = memberships
                .filter { $0.membershipStatus == .active }
                .reduce(into: [:]) { $0[$1.groupID, default: 0] += 1 }

            groups = groupList.map { group in
                PushRecipientItem(
                    id: "group_\(group.id)",
                    name: group.name,
                    memberCount: memberCountByGroup[group.id] ?? 0,
                    imageAssetName: group.imageAssetPath,
                    initials: String(group.name.prefix(2)).uppercased(),
                    isGroup: true
                )
            }
            let friendItems = friendList.map { friend in
                (person: friend, item: PushRecipientItem(
                    id: "friend_\(friend.id)",
                    name: friend.displayName,
                    memberCount: nil,
                    imageAssetName: friend.imageAssetPath,
                    initials: friend.initials,
                    isGroup: false
                ))
            }
            friends = friendItems.map(\.item)
            likelyFreeNow = friendItems.filter {
                let availability = statusByPersonID[$0.person.id]?.availability
                return availability == .freeNow || availability == .joinable
            }.map(\.item)
            mightBeInterested = friendItems.filter {
                let availability = statusByPersonID[$0.person.id]?.availability
                return availability == .maybeDown || availability == .freeSoon
            }.map(\.item)
            try await applyEditContextIfNeeded(container: container)
            loadState = .loaded(())
        } catch {
            loadState = .failed(error)
        }
    }

    func toggleRecipient(_ id: String) {
        if selectedRecipientIDs.contains(id) {
            selectedRecipientIDs.remove(id)
        } else {
            selectedRecipientIDs.insert(id)
        }
    }

    func isSelected(_ id: String) -> Bool {
        selectedRecipientIDs.contains(id)
    }

    func advance() {
        guard step < 4 else { return }
        step += 1
    }

    func goBack() {
        guard step > 1 else { return }
        if isEditMode && step == StartPushStep.confirmation {
            hasSubmitted = false
        }
        step -= 1
    }

    func editFromConfirmation() {
        step = 3
    }

    /// Submits the draft into shared local state. Called when the flow advances
    /// from step 3 to the confirmation step, so the push exists before step 4.
    func submit() async {
        guard let container, !hasSubmitted else { return }
        hasSubmitted = true
        let draft = PushDraft(
            title: pushText.trimmingCharacters(in: .whitespacesAndNewlines),
            recipientIDs: selectedRecipientIDs,
            startsAt: selectedTime,
            locationText: location.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            creatorID: container.currentUserID
        )
        do {
            if let editPlanID = launchContext.editPlanID {
                try await container.pushes.updatePush(planID: editPlanID, with: draft)
            } else {
                persistedPushID = try await container.pushes.createPush(draft)
            }
        } catch {
            // Local repo never throws; a real backend would surface this. Flag
            // stays true so a failed submit does not silently retry.
        }
    }

    /// Deletes the push behind this screen (edit mode, or a just-created
    /// draft on the confirmation step). No-op if nothing has been
    /// persisted yet, since there's nothing in Supabase to remove.
    func deletePush() async {
        guard let container, let persistedPushID else { return }
        try? await container.pushes.deletePush(planID: persistedPushID)
    }

    private func applyEditContextIfNeeded(container: AppDataContainer) async throws {
        guard let planID = launchContext.editPlanID else { return }
        let plans = try await container.pushes.activePlans()
        guard let plan = plans.first(where: { $0.id == planID }) else { return }
        let responses = try await container.pushes.responses()
        let places = try await container.pushes.allPlaces()
        pushText = plan.title
        selectedTime = plan.startsAt
        location = editLocation(for: plan, places: places)
        notes = plan.note ?? ""
        selectedRecipientIDs = editRecipientTokens(for: plan, responses: responses)
        step = StartPushStep.recipients
    }

    private func editLocation(for plan: PushPlan, places: [Place]) -> String {
        if let locationText = plan.locationText { return locationText }
        guard let placeID = plan.placeID else { return "" }
        return places.first { $0.id == placeID }?.name ?? ""
    }

    // The push's actual audience (`groupID`/`audience`) is the source of truth for who
    // it's addressed to, so it takes priority — deriving the selection from `.in`
    // responses instead would drop the group as soon as a single member accepted,
    // and re-picking the group in the edit UI would never stick on the next open.
    private func editRecipientTokens(for plan: PushPlan, responses: [PushResponse]) -> Set<String> {
        if let groupID = plan.groupID {
            return ["group_\(groupID)"]
        }
        let invitedPeople = responses.filter {
            $0.pushID == plan.id && $0.personID != plan.creatorID
        }
        if !invitedPeople.isEmpty {
            return Set(invitedPeople.map { "friend_\($0.personID)" })
        }
        return launchContext.editRecipientIDs
    }
}
