import Foundation
import Testing

@testable import Mercury

struct APIErrorMappingTests {
    @Test func knownCodesMapToLocalizedCopy() {
        let error = APIError.server(
            status: 401, code: .unauthorized, message: "Authentication required")
        #expect(error.errorDescription == String(localized: "Please sign in again."))

        let ai = APIError.server(status: 503, code: .aiUnavailable, message: "AI unavailable")
        #expect(
            ai.errorDescription
                == String(localized: "AI feedback is temporarily unavailable. Try again later."))
    }

    @Test func unknownCodesFallBackToServerMessage() {
        let error = APIError.server(
            status: 418, code: APIErrorCode(rawValue: "teapot"), message: "I'm a teapot")
        #expect(error.errorDescription == "I'm a teapot")
    }
}
