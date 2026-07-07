import Foundation
import Testing

@testable import Mercury

/// Fixtures under `Fixtures/` are captured from a live Mercury server by
/// `scripts/refresh-fixtures.sh`, so these tests pin the client models to the
/// real wire format. Assertions target what the capture script makes
/// deterministic (toeic onboarding, fresh account, seeded content shape) —
/// never run-dependent values like emails, timestamps, or random quiz draws.
struct DTODecodingTests {
    @Test func decodesMeWithSettings() throws {
        let me = try Fixtures.decode(MeResponse.self, from: "me")
        #expect(me.user.email.contains("@"))
        #expect(!me.user.id.isEmpty)
        #expect(me.settings?.activeTrack == .toeic)
        #expect(me.settings?.dailyGoal == 20)
        #expect(me.aiEnabled == false)
    }

    @Test func decodesFractionalSecondDates() throws {
        // Compare against the raw string in the fixture itself, so the test
        // proves fractional-second parsing without pinning a capture timestamp.
        // Tolerance, not string equality: ISO8601FormatStyle can round-trip
        // ".726" back out as ".725" (sub-millisecond float truncation).
        let raw = try JSONSerialization.jsonObject(with: Fixtures.data("me")) as? [String: Any]
        let rawDate = try #require((raw?["settings"] as? [String: Any])?["onboardedAt"] as? String)
        #expect(rawDate.contains("."), "fixture date lost its fractional seconds — recapture")

        let me = try Fixtures.decode(MeResponse.self, from: "me")
        let onboardedAt = try #require(me.settings?.onboardedAt)
        let expected = try Date(rawDate, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        #expect(abs(onboardedAt.timeIntervalSince(expected)) < 0.002)
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
        #expect(dashboard.streak == 1)
        let recent = try #require(dashboard.recentScores.first)
        #expect(recent.kind == .vocabQuiz)
        #expect(recent.score != nil)
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
        // The capture script trims to 6 words; the counts reflect a fresh account.
        #expect(overview.words.count == 6)
        #expect(overview.freshCount > 0)
        #expect(overview.dueCount == 0)
        #expect(overview.learnedCount == 0)
        let first = try #require(overview.words.first)
        #expect(!first.word.headword.isEmpty)
        #expect(!first.word.translationZh.isEmpty)
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
        // The capture answers randomly-ordered options, so only invariants hold.
        #expect(result.total == 10)
        #expect(result.score == result.correctWordIds.count)
        #expect((0...result.total).contains(result.score))
    }

    @Test func decodesErrorEnvelopes() throws {
        let unauthorized = try Fixtures.decode(ErrorEnvelope.self, from: "error-unauthorized")
        #expect(unauthorized.error.code == "unauthorized")

        let validation = try Fixtures.decode(ErrorEnvelope.self, from: "error-validation")
        #expect(validation.error.code == "validation_failed")
        #expect(!validation.error.message.isEmpty)
    }
}
