import Foundation
import Observation

@Observable
final class QuizViewModel {
    enum State: Equatable {
        case loading
        case empty
        case active
        case submitting
        case result(QuizResult)
        case loadFailed(String)
        case submitFailed(String)
    }

    private(set) var state: State = .loading
    private(set) var questions: [QuizQuestion] = []
    private(set) var index = 0
    private(set) var answers: [String: String] = [:]
    private var track: Track = .toeic

    private let api: any MercuryAPI

    init(api: any MercuryAPI) {
        self.api = api
    }

    var currentQuestion: QuizQuestion? {
        questions.indices.contains(index) ? questions[index] : nil
    }

    var progressText: String {
        "\(min(index + 1, questions.count)) / \(questions.count)"
    }

    func load() async {
        state = .loading
        do {
            let quiz = try await api.quiz()
            track = quiz.track
            questions = quiz.questions
            index = 0
            answers = [:]
            state = questions.isEmpty ? .empty : .active
        } catch {
            state = .loadFailed(error.localizedDescription)
        }
    }

    func select(_ option: QuizOption) async {
        guard state == .active, let question = currentQuestion else { return }
        answers[question.wordId] = option.wordId
        if index + 1 < questions.count {
            index += 1
        } else {
            await submit()
        }
    }

    /// Answers are kept on failure so submission can be retried.
    func submit() async {
        state = .submitting
        do {
            state = .result(try await api.submitQuiz(track: track, answers: answers))
        } catch {
            state = .submitFailed(error.localizedDescription)
        }
    }

    // MARK: - Result review

    func isCorrect(_ question: QuizQuestion, in result: QuizResult) -> Bool {
        result.correctWordIds.contains(question.wordId)
    }

    /// The correct option is the one for the quizzed word itself.
    func correctText(for question: QuizQuestion) -> String {
        question.options.first { $0.wordId == question.wordId }?.text ?? ""
    }

    func chosenText(for question: QuizQuestion) -> String? {
        guard let chosen = answers[question.wordId] else { return nil }
        return question.options.first { $0.wordId == chosen }?.text
    }
}
