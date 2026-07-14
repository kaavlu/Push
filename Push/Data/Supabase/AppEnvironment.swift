import Foundation

enum AppMode { case mock, live }

enum AppEnvironment {
    static let liveFlag = "--live"

    /// Release always live; Debug is mock unless `--live` is passed.
    static func resolve(isDebugBuild: Bool, arguments: [String]) -> AppMode {
        guard isDebugBuild else { return .live }
        return arguments.contains(liveFlag) ? .live : .mock
    }

    static var current: AppMode {
        #if DEBUG
        return resolve(isDebugBuild: true, arguments: ProcessInfo.processInfo.arguments)
        #else
        return resolve(isDebugBuild: false, arguments: ProcessInfo.processInfo.arguments)
        #endif
    }
}
