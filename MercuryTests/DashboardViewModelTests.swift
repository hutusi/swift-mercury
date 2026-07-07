import Foundation
import Testing
@testable import Mercury

struct DashboardViewModelTests {
    @Test func loadTransitionsToLoaded() async throws {
        let api = MockAPI()
        api.dashboardHandler = { try Fixtures.decode(DashboardResponse.self, from: "dashboard-after") }
        let model = DashboardViewModel(api: api)

        await model.load()

        guard case .loaded(let dashboard) = model.state else {
            Issue.record("expected .loaded, got \(model.state)")
            return
        }
        #expect(dashboard.streak == 1)
    }

    @Test func loadFailureShowsErrorOnlyWhenNothingLoaded() async throws {
        let api = MockAPI()
        api.dashboardHandler = { try Fixtures.decode(DashboardResponse.self, from: "dashboard") }
        let model = DashboardViewModel(api: api)
        await model.load()

        // A refresh failure must not blow away content already on screen.
        api.dashboardHandler = { throw APIError.transport(underlying: URLError(.timedOut)) }
        await model.load()

        guard case .loaded = model.state else {
            Issue.record("expected stale .loaded to survive refresh failure, got \(model.state)")
            return
        }
    }

    @Test func loadFailureWithoutContentIsFailed() async {
        let api = MockAPI()
        api.dashboardHandler = { throw APIError.transport(underlying: URLError(.timedOut)) }
        let model = DashboardViewModel(api: api)

        await model.load()

        guard case .failed = model.state else {
            Issue.record("expected .failed, got \(model.state)")
            return
        }
    }
}
