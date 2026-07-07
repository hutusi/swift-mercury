import SwiftUI

@main
struct MercuryApp: App {
    @State private var deps = AppDependencies()

    init() {
        #if DEBUG
        // UI-test hook: animations lose taps under automation.
        if ProcessInfo.processInfo.environment["MERCURY_DISABLE_ANIMATIONS"] == "1" {
            UIView.setAnimationsEnabled(false)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(deps: deps)
        }
    }
}
