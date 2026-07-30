//
//  CreatePostViewModel+EditCopy.swift
//  Push
//
//  Copy + action ids for Moments S9 existing-Moment edit / delete / leave.
//

import Foundation

enum CreatePostEditActionID {
    static let delete = "delete-moment"
    static let leave = "leave-moment"
}

enum CreatePostEditCopy {
    static let generic = "Couldn't save these changes. Try again."
    static let notAllowed = "You can't edit this moment anymore."
    static let notFound = "This moment is no longer available."
    static let conflict = "Someone else updated this moment. Pull to refresh and try again."
    static let cannotRemoveCreator = "The creator can't be removed from a moment."
    static let deniedTitle = "You can't edit this moment"
    static let deniedMessage = "Only people with edit access can change it."
    static let surfaceName = "this moment"
    static let deleteTitle = "Delete this moment?"
    static let deleteMessage = "It will disappear from the feed for everyone. This can't be undone."
    static let deleteConfirm = "Delete moment"
    static let leaveTitle = "Leave this moment?"
    static let leaveMessage = "You'll be untagged. Your photos stay, but you won't be able to add more."
    static let leaveConfirm = "Leave moment"
    static let overflowAccessibility = "Moment actions"
    static let deleteAction = "Delete moment"
    static let leaveAction = "Leave moment"
    static let editSuccessTitle = "Saved"
    static let editSuccessMessage = "Your changes are on the feed."

    static func message(for error: Error) -> String {
        guard let error = error as? MomentRepositoryError else { return generic }
        switch error {
        case .notAllowed, .notAuthenticated: return notAllowed
        case .notFound: return notFound
        case .conflict: return conflict
        case .cannotRemoveCreator: return cannotRemoveCreator
        case .invalidTag: return CreatePostPublishCopy.invalidTag
        default: return generic
        }
    }
}
