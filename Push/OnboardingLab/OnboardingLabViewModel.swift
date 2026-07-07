//
//  OnboardingLabViewModel.swift
//  Push
//
//  Drives navigation and per-screen state for the Onboarding Lab.
//  Mirrors the state machine of the web mock's `Component` class, but
//  as an MVVM view model so the screen views stay dumb.
//

#if DEBUG
import Foundation

@MainActor
final class OnboardingLabViewModel: ObservableObject {
    @Published private(set) var screen: OnboardingScreen = .welcome
    @Published private(set) var method: OnboardingAuthMethod?
    @Published private(set) var phone: String = ""
    @Published private(set) var code: String = ""
    @Published var name: String = ""
    @Published var handle: String = ""
    @Published private(set) var photoAdded = false
    @Published private(set) var privacy: OnboardingPrivacyOption = .exactActivity
    @Published private(set) var addedFriendIDs: Set<String> = []

    // Screens the user navigated through, for the in-frame back button.
    private var history: [OnboardingScreen] = []

    /// Jump straight to a screen via `--screen=<rawValue>` (e.g.
    /// `--onboardinglab --screen=privacy`) so a single step can be
    /// iterated on without walking the whole flow.
    init() {
        let prefix = "--screen="
        if let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
           let target = OnboardingScreen(rawValue: String(arg.dropFirst(prefix.count))) {
            screen = target
        }
    }

    private enum Limit {
        static let phoneDigits = 10
        static let codeDigits = 4
        static let codeAdvanceDelay: TimeInterval = 0.46
    }

    // MARK: Navigation

    /// Push a screen and remember where we came from.
    func go(to next: OnboardingScreen) {
        history.append(screen)
        screen = next
    }

    func back() {
        guard let previous = history.popLast() else {
            screen = .welcome
            return
        }
        screen = previous
    }

    // MARK: Welcome → auth → preview

    func choose(_ method: OnboardingAuthMethod) {
        self.method = method
        go(to: method == .mobile ? .phone : .preview)
    }

    func continueFromPreview() {
        go(to: .profile)
    }

    // MARK: Phone + verify keypad

    func pressDigit(_ digit: Int) {
        switch screen {
        case .phone:
            guard phone.count < Limit.phoneDigits else { return }
            phone.append(String(digit))
        case .verify:
            guard code.count < Limit.codeDigits else { return }
            code.append(String(digit))
            if code.count == Limit.codeDigits { scheduleVerifyAdvance() }
        default:
            break
        }
    }

    func deleteDigit() {
        switch screen {
        case .phone: _ = phone.popLast()
        case .verify: _ = code.popLast()
        default: break
        }
    }

    private func scheduleVerifyAdvance() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Limit.codeAdvanceDelay * 1_000_000_000))
            guard screen == .verify else { return }
            go(to: .preview)
        }
    }

    /// Formatted as (555) 012-3456 for display; empty string when blank.
    var formattedPhone: String {
        Self.format(phone)
    }

    /// Number echoed on the verify screen, falling back to a sample.
    var verifyNumber: String {
        "+1 " + (phone.isEmpty ? "(555) 012-3456" : formattedPhone)
    }

    private static func format(_ digits: String) -> String {
        guard !digits.isEmpty else { return "" }
        let area = digits.prefix(3)
        let middle = digits.dropFirst(3).prefix(3)
        let last = digits.dropFirst(6).prefix(4)
        var result = ""
        if !area.isEmpty { result += "(\(area)" + (area.count == 3 ? ") " : "") }
        if !middle.isEmpty { result += middle + (middle.count == 3 && !last.isEmpty ? "-" : "") }
        result += last
        return result
    }

    // MARK: Profile

    func togglePhoto() {
        photoAdded.toggle()
    }

    /// Handle is lowercased and stripped to the allowed character set.
    func setHandle(_ raw: String) {
        handle = raw.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
    }

    // MARK: Privacy

    func select(_ option: OnboardingPrivacyOption) {
        privacy = option
    }

    // MARK: Add friends

    func toggleFriend(_ id: String) {
        if addedFriendIDs.contains(id) {
            addedFriendIDs.remove(id)
        } else {
            addedFriendIDs.insert(id)
        }
    }

    func isAdded(_ id: String) -> Bool {
        addedFriendIDs.contains(id)
    }

    var addedCount: Int { addedFriendIDs.count }

    var friendsCTALabel: String {
        guard addedCount > 0 else { return "Continue" }
        return "Continue with \(addedCount) friend\(addedCount == 1 ? "" : "s")"
    }

    // MARK: Reset

    func restart() {
        screen = .welcome
        history = []
        method = nil
        phone = ""
        code = ""
        name = ""
        handle = ""
        photoAdded = false
        privacy = .exactActivity
        addedFriendIDs = []
    }
}
#endif
