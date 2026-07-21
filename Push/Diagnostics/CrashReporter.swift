//
//  CrashReporter.swift
//  Push
//
//  Subscribes to MetricKit diagnostic payloads (crash/hang reports) and logs
//  their presence via PushLog. Apple delivers these on next launch after a
//  crash or hang on a real device — at least once per day when conditions
//  permit, never guaranteed. No third-party dependency, no account, no PII:
//  MetricKit diagnostics are aggregate stack signatures and durations, not
//  user data.
//

import Foundation
import MetricKit

final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashReporter()

    private override init() {}

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let crashCount = payload.crashDiagnostics?.count ?? 0
            let hangCount = payload.hangDiagnostics?.count ?? 0
            guard crashCount > 0 || hangCount > 0 else { continue }
            PushLog.bootstrap.error(
                "MetricKit payload: \(crashCount, privacy: .public) crash diagnostic(s), \(hangCount, privacy: .public) hang diagnostic(s)"
            )
        }
    }
}
