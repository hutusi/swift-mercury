import Foundation
import Observation

@Observable
final class DashboardViewModel {
    enum State {
        case loading
        case loaded(DashboardResponse)
        case failed(String)
    }

    private(set) var state: State = .loading
    private let api: any MercuryAPI

    init(api: any MercuryAPI) {
        self.api = api
    }

    func load() async {
        do {
            state = .loaded(try await api.dashboard())
        } catch {
            // Keep stale content on pull-to-refresh failures; only show the
            // error screen when there is nothing to display.
            if case .loaded = state { return }
            state = .failed(error.localizedDescription)
        }
    }

    func reload() async {
        state = .loading
        await load()
    }
}
