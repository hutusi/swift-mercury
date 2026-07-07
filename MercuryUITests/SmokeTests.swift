import XCTest

/// End-to-end smoke test against a LIVE Mercury backend.
/// Set TEST_RUNNER_MERCURY_BASE_URL to point somewhere other than the default
/// http://localhost:3000. Registers a fresh throwaway account each run.
final class SmokeTests: XCTestCase {
    private var baseURL: String {
        ProcessInfo.processInfo.environment["MERCURY_BASE_URL"] ?? "http://localhost:3000"
    }

    /// Fails fast with a clear message when the backend isn't reachable.
    private func assertBackendReachable() throws {
        let url = URL(string: baseURL + "/api/v1/me")!
        let expectation = expectation(description: "backend probe")
        var status: Int?
        URLSession.shared.dataTask(with: url) { _, response, _ in
            status = (response as? HTTPURLResponse)?.statusCode
            expectation.fulfill()
        }.resume()
        wait(for: [expectation], timeout: 10)
        guard status == 401 else {
            throw XCTSkip(
                "Mercury backend not reachable at \(baseURL) (got \(status.map(String.init) ?? "no response"), expected 401) — start it or set TEST_RUNNER_MERCURY_BASE_URL"
            )
        }
    }

    @MainActor
    func testRegisterOnboardDashboardStudyFlow() throws {
        try assertBackendReachable()

        let app = XCUIApplication()
        app.launchEnvironment["MERCURY_BASE_URL_OVERRIDE"] = baseURL
        app.launchEnvironment["MERCURY_RESET_SESSION"] = "1"
        app.launchEnvironment["MERCURY_DISABLE_ANIMATIONS"] = "1"
        app.launch()

        // Register a unique throwaway account.
        let createAccountLink = app.buttons["New to Mercury? Create an account"]
        XCTAssertTrue(createAccountLink.waitForExistence(timeout: 10), "login screen did not appear")
        createAccountLink.tap()

        let email = "ios-smoke-\(Int(Date().timeIntervalSince1970))@example.com"
        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("iOS Smoke")
        app.textFields["Email"].tap()
        app.textFields["Email"].typeText(email)
        app.secureTextFields["Password (8+ characters)"].tap()
        app.secureTextFields["Password (8+ characters)"].typeText("password123")
        app.buttons["Create Account"].tap()

        // Onboarding: pick TOEIC. Wait out the keyboard dismissal first —
        // taps at stale coordinates get lost.
        let toeicButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'TOEIC'")).firstMatch
        XCTAssertTrue(toeicButton.waitForExistence(timeout: 15), "onboarding did not appear — is the backend running?")
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 5)
        toeicButton.tap()

        let welcome = app.staticTexts["Welcome to Mercury!"]
        for _ in 0..<2 where !welcome.waitForExistence(timeout: 8) {
            if toeicButton.exists { toeicButton.tap() }
        }
        XCTAssertTrue(welcome.waitForExistence(timeout: 15), "dashboard did not appear after onboarding")

        // Study one card: flip, then grade.
        let vocabTab = app.tabBars.buttons["Vocabulary"]
        vocabTab.tap()
        let studyButton = app.buttons["Study New Words"]
        if !studyButton.waitForExistence(timeout: 10) {
            vocabTab.tap()  // the floating tab bar can swallow a tap while settling
        }
        XCTAssertTrue(studyButton.waitForExistence(timeout: 10), "vocab overview did not appear")
        studyButton.tap()

        let revealHint = app.staticTexts["Tap to reveal"]
        XCTAssertTrue(revealHint.waitForExistence(timeout: 10), "flashcard did not appear")
        revealHint.tap()

        let goodButton = app.buttons["Good"]
        XCTAssertTrue(goodButton.waitForExistence(timeout: 5), "grade bar did not appear after flip")
        goodButton.tap()

        // Grading advanced: either the next card's front or the finish screen.
        let nextCard = app.staticTexts["Tap to reveal"]
        let finished = app.staticTexts["Session Complete"]
        XCTAssertTrue(
            nextCard.waitForExistence(timeout: 10) || finished.exists,
            "grading did not advance the session"
        )
    }

}
