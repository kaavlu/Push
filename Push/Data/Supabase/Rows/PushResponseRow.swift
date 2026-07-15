//
//  PushResponseRow.swift
//  Push
//

import Foundation

/// PostgREST row shape for `push_responses`. Property names match the
/// table's snake_case columns directly so no `CodingKeys` are needed.
///
/// `responded_at` is decoded as `String?`, not `Date?`: `JSONDecoder`'s
/// default date strategy expects a numeric timestamp and would fail to
/// decode an ISO-8601 string, and real PostgREST responses use
/// fractional-second timestamps (e.g. "2026-07-13T11:24:18.230123+00:00").
/// Decoding as a plain optional string sidesteps the decoder's date strategy
/// entirely and lets `parsedRespondedAt()` handle both forms explicitly.
struct PushResponseRow: Decodable {
    let id: String
    let push_id: String
    let person_id: String
    let response: String
    let responded_at: String?
    let ready_state: String

    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private func parsedRespondedAt() -> Date? {
        guard let responded_at else { return nil }
        return Self.isoFractional.date(from: responded_at) ?? Self.isoPlain.date(from: responded_at)
    }

    func pushResponse() -> PushResponse {
        PushResponse(
            id: id,
            pushID: push_id,
            personID: person_id,
            response: PushResponse.Response(rawValue: response) ?? .pending,
            respondedAt: parsedRespondedAt(),
            readyState: mapReadyState(ready_state)
        )
    }

    // rawValues differ in casing style ("ready_now" vs `readyNow`) so they
    // can't round-trip through `init(rawValue:)` — bridge explicitly.
    private func mapReadyState(_ raw: String) -> PushResponse.ReadyState {
        switch raw {
        case "ready_now": return .readyNow
        case "ready_later": return .readyLater
        case "needs_ride": return .needsRide
        case "not_ready": return .notReady
        default: return .unknown
        }
    }
}
