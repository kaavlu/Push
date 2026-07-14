// Push/Auth/AuthFormModel.swift
import Foundation

/// Shared surface the promoted onboarding auth views bind to, so the same
/// screen serves the production AuthViewModel and the DEBUG lab view model.
@MainActor
protocol AuthFormModel: ObservableObject {
    var email: String { get set }
    var password: String { get set }
    var errorMessage: String? { get }
    var canSubmit: Bool { get }
    func submitPrimary() async
}

extension AuthViewModel: AuthFormModel {
    func submitPrimary() async { await submitSignIn() }
}
