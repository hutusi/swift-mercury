import Foundation
import Testing
@testable import Mercury

struct KeychainTokenStoreTests {
    @Test func roundTripsSaveLoadClear() {
        let store = KeychainTokenStore(
            service: "com.hutusi.mercury.tests",
            account: "roundtrip-\(UUID().uuidString)"
        )
        defer { store.clear() }

        #expect(store.load() == nil)

        store.save("first-token")
        #expect(store.load() == "first-token")

        store.save("second-token")
        #expect(store.load() == "second-token")

        store.clear()
        #expect(store.load() == nil)
    }
}
