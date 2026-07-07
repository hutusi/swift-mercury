import Foundation

struct AppConfig {
    let baseURL: URL

    /// DEBUG-only UserDefaults key that overrides the built-in base URL,
    /// editable from the Profile screen. Changing servers invalidates the token.
    static let baseURLOverrideKey = "debug.baseURLOverride"

    static func load() -> AppConfig {
        #if DEBUG
        // UI tests inject the server via launch environment.
        if let env = ProcessInfo.processInfo.environment["MERCURY_BASE_URL_OVERRIDE"],
           let url = URL(string: env), url.scheme != nil {
            return AppConfig(baseURL: url)
        }
        if let override = UserDefaults.standard.string(forKey: baseURLOverrideKey),
           let url = URL(string: override), url.scheme != nil {
            return AppConfig(baseURL: url)
        }
        #endif
        guard let string = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
              let url = URL(string: string), url.scheme != nil else {
            fatalError("APIBaseURL missing or malformed in Info.plist — check Config/*.xcconfig")
        }
        return AppConfig(baseURL: url)
    }
}
