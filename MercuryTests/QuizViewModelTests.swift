import Foundation
import Testing
@testable import Mercury

struct QuizViewModelTests {
    private func makeQuestion(_ wordId: String, correctText: String) -> QuizQuestion {
        QuizQuestion(
            wordId: wordId,
            direction: .en2zh,
            prompt: "prompt-\(wordId)",
            options: [
                QuizOption(wordId: wordId, text: correctText),
                QuizOption(wordId: "other-1", text: "wrong 1"),
                QuizOption(wordId: "other-2", text: "wrong 2"),
                QuizOption(wordId: "other-3", text: "wrong 3"),
            ]
        )
    }

    @Test func selectingRecordsAnswerAndAdvances() async {
        let api = MockAPI()
        api.quizHandler = {
            QuizResponse(track: .toeic, questions: [
                self.makeQuestion("w1", correctText: "right 1"),
                self.makeQuestion("w2", correctText: "right 2"),
            ])
        }
        let model = QuizViewModel(api: api)
        await model.load()
        #expect(!model.hasUnsavedProgress)

        await model.select(QuizOption(wordId: "other-1", text: "wrong 1"))

        #expect(model.answers == ["w1": "other-1"])
        #expect(model.currentQuestion?.wordId == "w2")
        #expect(model.state == .active)
        #expect(model.hasUnsavedProgress)
    }

    @Test func answeringLastQuestionSubmitsWithTrackAndAnswers() async {
        let api = MockAPI()
        api.quizHandler = {
            QuizResponse(track: .ielts, questions: [self.makeQuestion("w1", correctText: "right")])
        }
        var submitted: (Track, [String: String])?
        api.submitQuizHandler = { track, answers in
            submitted = (track, answers)
            return QuizResult(score: 1, total: 1, correctWordIds: ["w1"])
        }
        let model = QuizViewModel(api: api)
        await model.load()

        await model.select(QuizOption(wordId: "w1", text: "right"))

        #expect(submitted?.0 == .ielts)
        #expect(submitted?.1 == ["w1": "w1"])
        #expect(model.state == .result(QuizResult(score: 1, total: 1, correctWordIds: ["w1"])))
    }

    @Test func emptyPoolShowsEmptyState() async {
        let api = MockAPI()
        api.quizHandler = { QuizResponse(track: .toeic, questions: []) }
        let model = QuizViewModel(api: api)

        await model.load()

        #expect(model.state == .empty)
    }

    @Test func failedSubmitKeepsAnswersForRetry() async {
        let api = MockAPI()
        api.quizHandler = {
            QuizResponse(track: .toeic, questions: [self.makeQuestion("w1", correctText: "right")])
        }
        var attempts = 0
        api.submitQuizHandler = { _, answers in
            attempts += 1
            if attempts == 1 {
                throw APIError.transport(underlying: URLError(.timedOut))
            }
            return QuizResult(score: 0, total: 1, correctWordIds: [])
        }
        let model = QuizViewModel(api: api)
        await model.load()

        await model.select(QuizOption(wordId: "other-1", text: "wrong 1"))

        guard case .submitFailed = model.state else {
            Issue.record("expected .submitFailed, got \(model.state)")
            return
        }
        #expect(model.answers == ["w1": "other-1"])
        #expect(model.hasUnsavedProgress)

        await model.submit()

        guard case .result = model.state else {
            Issue.record("expected .result after retry, got \(model.state)")
            return
        }
        #expect(!model.hasUnsavedProgress)
    }

    @Test func resultReviewHelpers() async {
        let api = MockAPI()
        let question = makeQuestion("w1", correctText: "正确")
        api.quizHandler = { QuizResponse(track: .toeic, questions: [question]) }
        let model = QuizViewModel(api: api)
        await model.load()
        api.submitQuizHandler = { _, _ in QuizResult(score: 0, total: 1, correctWordIds: []) }
        await model.select(QuizOption(wordId: "other-2", text: "wrong 2"))

        let result = QuizResult(score: 0, total: 1, correctWordIds: [])
        #expect(!model.isCorrect(question, in: result))
        #expect(model.correctText(for: question) == "正确")
        #expect(model.chosenText(for: question) == "wrong 2")
    }
}
