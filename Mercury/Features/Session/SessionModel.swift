import Foundation
import Observation

/// Single source of truth for the auth lifecycle; RootView switches on `phase`.
@Observable
final class SessionModel {
    enum Phase: Equatable {
        case loading
        case failed(String)
        case signedOut
        case onboardingRequired
        case ready
    }

    private(set) var phase: Phase = .loading
    private(set) var me: MeResponse?

    private let api: any MercuryAPI
    private let auth: AuthService
    private let tokenStore: any TokenStore

    init(api: any MercuryAPI, auth: AuthService, tokenStore: any TokenStore) {
        self.api = api
        self.auth = auth
        self.tokenStore = tokenStore
    }

    func bootstrap() async {
        guard tokenStore.load() != nil else {
            phase = .signedOut
            return
        }
        phase = .loading
        await refreshMe()
    }

    /// Throws so the login form can show the failure inline; on success the
    /// phase moves to onboarding or ready.
    func signIn(email: String, password: String) async throws {
        let token = try await auth.signIn(email: email, password: password)
        tokenStore.save(token)
        await refreshMe()
    }

    func signUp(name: String, email: String, password: String) async throws {
        let token = try await auth.signUp(name: name, email: email, password: password)
        tokenStore.save(token)
        await refreshMe()
    }

    func completeOnboarding(track: Track) async throws {
        let settings = try await api.updateSettings(track: track)
        if let current = me {
            me = MeResponse(user: current.user, settings: settings, aiEnabled: current.aiEnabled)
        }
        phase = .ready
    }

    func changeTrack(_ track: Track) async throws {
        let settings = try await api.updateSettings(track: track)
        if let current = me {
            me = MeResponse(user: current.user, settings: settings, aiEnabled: current.aiEnabled)
        }
    }

    func signOut() async {
        if let token = tokenStore.load() {
            await auth.signOut(token: token)
        }
        forceSignOut()
    }

    /// Also wired to APIClient.onUnauthorized: any 401 lands back on login.
    func forceSignOut() {
        tokenStore.clear()
        me = nil
        phase = .signedOut
    }

    private func refreshMe() async {
        do {
            let response = try await api.me()
            me = response
            phase = response.settings == nil ? .onboardingRequired : .ready
        } catch {
            if case .server(let status, _, _) = error as? APIError, status == 401 {
                forceSignOut()
                return
            }
            phase = .failed(error.localizedDescription)
        }
    }
}
