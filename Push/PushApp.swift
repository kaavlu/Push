//
//  PushApp.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/28/26.
//

import SwiftUI


@main
struct PushApp: App {
    init() {
        CrashReporter.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            PushAdaptiveLayoutReader {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--pucklab") {
                    PuckLabView()
                } else if ProcessInfo.processInfo.arguments.contains("--onboardinglab") {
                    OnboardingLabView()
                } else if ProcessInfo.processInfo.arguments.contains("--friends") {
                    FriendsView()
                } else {
                    RootView()
                }
                #else
                RootView()
                #endif
            }
        }
    }
}
