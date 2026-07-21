//
//  PushLifecycle.swift
//  Push
//
//  Time-derived active / historical / happening rules for Pushes.
//  Read-time only — no cron and no reliance on persisted `PushPlan.state`.
//

import Foundation

enum PushLifecycle {

    /// Still on Active surfaces: not cancelled and not yet past `expiresAt`.
    static func isActive(_ plan: PushPlan, now: Date) -> Bool {
        plan.cancelledAt == nil && now < plan.expiresAt
    }

    /// Completed History/calendar candidate: not cancelled and past expiry.
    static func isHistorical(_ plan: PushPlan, now: Date) -> Bool {
        plan.cancelledAt == nil && now >= plan.expiresAt
    }

    /// Scheduled window has started but the push has not expired.
    static func isHappening(_ plan: PushPlan, now: Date) -> Bool {
        isActive(plan, now: now) && now >= plan.startsAt
    }

    /// Presentation phase while active; `nil` when cancelled or historical.
    static func phase(_ plan: PushPlan, now: Date) -> PushPlan.State? {
        guard isActive(plan, now: now) else { return nil }
        return isHappening(plan, now: now) ? .happening : .collecting
    }
}
