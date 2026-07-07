import Foundation
import Testing

@testable import Mercury

/// Fixtures under `Fixtures/` are captured verbatim from a live Mercury server
/// (see repo README), so these tests pin the client models to the real wire format.
struct DTODecodingTests {
    @Test func decodesMeWithSettings() throws {
        let me = try Fixtures.decode(MeResponse.self, from: "me")
        #expect(me.user.email == "ios-fixture@example.com")
        #expect(me.settings?.activeTrack == .toeic)
        #expect(me.settings?.dailyGoal == 20)
        #expect(me.aiEnabled == false)
    }

    @Test func decodesFractionalSecondDates() throws {
        let me = try Fixtures.decode(MeResponse.self, from: "me")
        let onboardedAt = try #require(me.settings?.onboardedAt)
        let roundTripped = onboardedAt.formatted(
            Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        )
        #expect(roundTripped == "2026-07-07T01:24:38.212Z")
    }

    @Test func decodesMeBeforeOnboarding() throws {
        let me = try Fixtures.decode(MeResponse.self, from: "me-pre-onboarding")
        #expect(me.settings == nil)
    }

    @Test func decodesSettingsResponse() throws {
        let response = try Fixtures.decode(SettingsResponse.self, from: "settings")
        #expect(response.settings.activeTrack == .toeic)
    }

    @Test func decodesNewUserDashboard() throws {
        let dashboard = try Fixtures.decode(DashboardResponse.self, from: "dashboard")
        #expect(dashboard.isNewUser)
        #expect(dashboard.streak == 0)
        #expect(dashboard.inProgressExamId == nil)
        #expect(dashboard.lastExamEstimate == nil)
        #expect(dashboard.recentScores.isEmpty)
    }

    @Test func decodesDashboardWithQuizScore() throws {
        let dashboard = try Fixtures.decode(DashboardResponse.self, from: "dashboard-after")
        let recent = try #require(dashboard.recentScores.first)
        #expect(recent.kind == .vocabQuiz)
        #expect(recent.score == 2)
        #expect(recent.total == 10)
        #expect(recent.scoreLabel == nil)
        #expect(recent.estimate == nil)
    }

    @Test func unknownScoreKindDoesNotFailDecoding() throws {
        let json = """
            {"kind": "pronunciation", "at": "2026-07-07T01:00:00.000Z", "scoreLabel": null}
            """
        let score = try Fixtures.decode(RecentScore.self, fromJSON: json)
        #expect(score.kind == .unknown("pronunciation"))
    }

    @Test func decodesWritingScoreWithLabel() throws {
        let json = """
            {"kind": "writing", "at": "2026-07-07T01:00:00.000Z", "scoreLabel": "Band 6.5"}
            """
        let score = try Fixtures.decode(RecentScore.self, fromJSON: json)
        #expect(score.kind == .writing)
        #expect(score.scoreLabel == "Band 6.5")
        #expect(score.score == nil)
    }

    @Test func decodesToeicEstimate() throws {
        let json = """
            {"kind": "toeic", "listening": 320, "reading": 290, "total": 610}
            """
        let estimate = try Fixtures.decode(ExamEstimate.self, fromJSON: json)
        #expect(estimate == .toeic(listening: 320, reading: 290, total: 610))
    }

    @Test func decodesIeltsEstimate() throws {
        let json = """
            {"kind": "ielts", "band": 6.5}
            """
        let estimate = try Fixtures.decode(ExamEstimate.self, fromJSON: json)
        #expect(estimate == .ielts(band: 6.5))
    }

    @Test func decodesVocabOverview() throws {
        let overview = try Fixtures.decode(VocabOverview.self, from: "vocab-overview")
        #expect(overview.words.count == 6)
        #expect(overview.freshCount == 100)
        let first = try #require(overview.words.first)
        #expect(first.word.headword == "invoice")
        #expect(first.word.translationZh == "发票；账单")
        #expect(first.started == false)
        #expect(first.due == false)
    }

    @Test func decodesStudyQueue() throws {
        let queue = try Fixtures.decode(StudyQueue.self, from: "study-queue")
        let first = try #require(queue.cards.first)
        #expect(first.wordId == first.word.id)
        #expect(first.isNew)
        #expect(!first.word.exampleZh.isEmpty)
    }

    @Test func decodesGradeResponse() throws {
        let response = try Fixtures.decode(GradeResponse.self, from: "grade")
        #expect(response.intervalDays == 1)
    }

    @Test func decodesQuiz() throws {
        let quiz = try Fixtures.decode(QuizResponse.self, from: "quiz")
        #expect(quiz.track == .toeic)
        #expect(quiz.questions.count == 10)
        for question in quiz.questions {
            #expect(question.options.count == 4)
            #expect(question.options.contains { $0.wordId == question.wordId })
        }
    }

    @Test func decodesQuizResult() throws {
        let result = try Fixtures.decode(QuizResult.self, from: "quiz-result")
        #expect(result.score == 2)
        #expect(result.total == 10)
        #expect(result.correctWordIds.count == 2)
    }

    @Test func decodesErrorEnvelopes() throws {
        let unauthorized = try Fixtures.decode(ErrorEnvelope.self, from: "error-unauthorized")
        #expect(unauthorized.error.code == "unauthorized")

        let validation = try Fixtures.decode(ErrorEnvelope.self, from: "error-validation")
        #expect(validation.error.code == "validation_failed")
        #expect(!validation.error.message.isEmpty)
    }
}
