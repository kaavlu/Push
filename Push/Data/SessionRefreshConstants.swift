import Foundation

enum SessionRefreshConstants {
    /// Minimum time after a successful session re-warm before another
    /// *scheduled* refresh starts new network work.
    static let minimumInterval: TimeInterval = 2
}
