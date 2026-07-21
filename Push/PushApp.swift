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
                debugRootView()
                #else
                RootView()
                #endif
            }
        }
    }

    #if DEBUG
    /// DEBUG launch shortcuts for previews and screenshots (pass after `--` to run-ios-sim).
    @ViewBuilder
    private func debugRootView() -> some View {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--pucklab") {
            PuckLabView()
        } else if args.contains("--onboardinglab") {
            OnboardingLabView()
        } else if args.contains("--friends") {
            FriendsView()
        } else if args.contains("--plans") {
            PlansView()
        } else if args.contains("--profile") {
            ProfileView()
        } else if args.contains("--alerts") {
            AlertsView()
        } else {
            RootView()
        }
    }
    #endif
}
