import Foundation

enum AppVersionInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    static var versionText: String {
        "v\(version)"
    }

    static var buildText: String {
        "Build \(build)"
    }
}
