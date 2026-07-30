// Push/Data/Contacts/DeviceContactsProvider.swift
import Contacts
import Foundation

/// Live Contacts framework wrapper. Does not upload the address book.
@MainActor
final class DeviceContactsProvider: ContactsProviding {
    private let store = CNContactStore()

    func authorizationState() -> ContactsAuthorizationState {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    func requestAccess() async -> Bool {
        switch authorizationState() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                store.requestAccess(for: .contacts) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func fetchMatchHints(limit: Int) async throws -> [ContactMatchHint] {
        let capped = min(max(limit, 1), DeviceContactsLimit.maxHints)
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .givenName

        var hints: [ContactMatchHint] = []
        try store.enumerateContacts(with: request) { contact, stop in
            guard hints.count < capped else {
                stop.pointee = true
                return
            }
            let given = contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
            let family = contact.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
            let display: String
            if !given.isEmpty {
                display = given
            } else if !family.isEmpty {
                display = family
            } else {
                return
            }
            let phone = contact.phoneNumbers.first.map {
                $0.value.stringValue.filter(\.isNumber)
            }
            hints.append(
                ContactMatchHint(
                    id: contact.identifier,
                    displayName: display,
                    phoneDigits: phone?.isEmpty == true ? nil : phone
                )
            )
        }
        return hints
    }
}

private enum DeviceContactsLimit {
    static let maxHints = 50
}
