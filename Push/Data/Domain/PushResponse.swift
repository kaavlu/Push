//
//  PushResponse.swift
//  Push
//

import Foundation

struct PushResponse: Identifiable, Codable, Equatable {
    enum Response: String, Codable { case `in`, maybe, out, pending }
    enum ReadyState: String, Codable { case readyNow, readyLater, needsRide, notReady, unknown }

    let id: String
    let pushID: PushPlan.ID
    let personID: Person.ID
    let response: Response
    let respondedAt: Date?
    let readyState: ReadyState
}
