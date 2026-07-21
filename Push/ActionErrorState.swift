import Foundation

/// Presentation model for a recoverable user-initiated mutation failure.
/// Retry payloads live on the owning ViewModel; this type stays Equatable for UI.
struct ActionErrorState: Equatable {
    let message: String
}
