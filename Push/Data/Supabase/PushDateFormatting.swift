//
//  PushDateFormatting.swift
//  Push
//
//  Shared ISO-8601 (fractional-seconds) string encoding for push write
//  payloads, mirroring the fractional-first parsing `PushRow`/`PushResponseRow`
//  use on the read side so round-tripped timestamps stay in the format
//  PostgREST expects.
//

import Foundation

enum PushDateFormatting {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func string(_ date: Date) -> String {
        formatter.string(from: date)
    }
}
