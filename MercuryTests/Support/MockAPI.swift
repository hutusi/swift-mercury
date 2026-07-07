import Foundation
@testable import Mercury

/// Closure-backed MercuryAPI double for view-model tests. Unstubbed calls throw.
final class MockAPI: MercuryAPI {
    struct Unstubbed: Error {
        let method: String
    }

    var meHandler: (() throws -> MeResponse)?
    var updateSettingsHandler: ((Track) throws -> UserSettings)?
    var dashboardHandler: (() throws -> DashboardResponse)?
    var vocabOverviewHandler: (() throws -> VocabOverview)?
    var studyQueueHandler: (() throws -> [StudyCard])?
    var gradeHandler: ((String, Grade) throws -> Int)?
    var quizHandler: (() throws -> QuizResponse)?
    var submitQuizHandler: ((Track, [String: String]) throws -> QuizResult)?

    func me() async throws -> MeResponse {
        guard let meHandler else { throw Unstubbed(method: "me") }
        return try meHandler()
    }

    func updateSettings(track: Track) async throws -> UserSettings {
        guard let updateSettingsHandler else { throw Unstubbed(method: "updateSettings") }
        return try updateSettingsHandler(track)
    }

    func dashboard() async throws -> DashboardResponse {
        guard let dashboardHandler else { throw Unstubbed(method: "dashboard") }
        return try dashboardHandler()
    }

    func vocabOverview() async throws -> VocabOverview {
        guard let vocabOverviewHandler else { throw Unstubbed(method: "vocabOverview") }
        return try vocabOverviewHandler()
    }

    func studyQueue() async throws -> [StudyCard] {
        guard let studyQueueHandler else { throw Unstubbed(method: "studyQueue") }
        return try studyQueueHandler()
    }

    func grade(wordId: String, grade: Grade) async throws -> Int {
        guard let gradeHandler else { throw Unstubbed(method: "grade") }
        return try gradeHandler(wordId, grade)
    }

    func quiz() async throws -> QuizResponse {
        guard let quizHandler else { throw Unstubbed(method: "quiz") }
        return try quizHandler()
    }

    func submitQuiz(track: Track, answers: [String: String]) async throws -> QuizResult {
        guard let submitQuizHandler else { throw Unstubbed(method: "submitQuiz") }
        return try submitQuizHandler(track, answers)
    }
}

// MARK: - Builders

extension MeResponse {
    static func fixture(settings: UserSettings? = .fixture()) -> MeResponse {
        MeResponse(
            user: UserProfile(id: "user-1", name: "Test User", email: "test@example.com"),
            settings: settings,
            aiEnabled: false
        )
    }
}

extension UserSettings {
    static func fixture(track: Track = .toeic) -> UserSettings {
        UserSettings(activeTrack: track, dailyGoal: 20, onboardedAt: Date(timeIntervalSince1970: 1_780_000_000))
    }
}

extension VocabWord {
    static func fixture(id: String = "toeic-w-001", headword: String = "invoice") -> VocabWord {
        VocabWord(
            id: id, track: .toeic, topic: "office", headword: headword,
            ipa: "/ˈɪnvɔɪs/", pos: "n.",
            definitionEn: "A document listing goods or services provided and the amount due.",
            translationZh: "发票；账单",
            exampleEn: "Please send the invoice to our accounting department by Friday.",
            exampleZh: "请在周五前把发票发给我们的财务部门。"
        )
    }
}

extension StudyCard {
    static func fixture(id: String = "toeic-w-001", isNew: Bool = true) -> StudyCard {
        StudyCard(word: .fixture(id: id), wordId: id, isNew: isNew)
    }
}
