import Foundation

/// Composition root. Built once at launch by MercuryApp.
final class AppDependencies {
    let tokenStore: any TokenStore
    let api: APIClient
    let auth: AuthService
    let session: SessionModel

    init() {
        let config = AppConfig.load()
        tokenStore = KeychainTokenStore()
        #if DEBUG
        // UI-test hook: guarantee a signed-out start regardless of leftover state.
        if ProcessInfo.processInfo.environment["MERCURY_RESET_SESSION"] == "1" {
            tokenStore.clear()
        }
        #endif
        api = APIClient(baseURL: config.baseURL, tokenStore: tokenStore)
        auth = AuthService(baseURL: config.baseURL)
        session = SessionModel(api: api, auth: auth, tokenStore: tokenStore)
        api.onUnauthorized = { [weak session] in
            session?.forceSignOut()
        }
    }
}
