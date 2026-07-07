import Foundation
import Observation

@Observable
final class StudySessionViewModel {
    enum State: Equatable {
        case loading
        case empty
        case studying
        case finished(reviewed: Int)
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var cards: [StudyCard] = []
    private(set) var index = 0
    private(set) var isFlipped = false
    private(set) var isGrading = false
    private(set) var gradeError: String?

    private let api: any MercuryAPI

    init(api: any MercuryAPI) {
        self.api = api
    }

    var currentCard: StudyCard? {
        cards.indices.contains(index) ? cards[index] : nil
    }

    var progressText: String {
        "\(min(index + 1, cards.count)) / \(cards.count)"
    }

    var hasStartedGrading: Bool {
        index > 0
    }

    func load() async {
        state = .loading
        do {
            cards = try await api.studyQueue()
            index = 0
            isFlipped = false
            state = cards.isEmpty ? .empty : .studying
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func flip() {
        isFlipped.toggle()
    }

    /// On failure the card stays put so the same grade can be retried — the
    /// server's grade transaction is designed to be retried safely.
    func grade(_ grade: Grade) async {
        guard let card = currentCard, !isGrading else { return }
        isGrading = true
        gradeError = nil
        defer { isGrading = false }
        do {
            _ = try await api.grade(wordId: card.wordId, grade: grade)
            advance()
        } catch {
            gradeError = error.localizedDescription
        }
    }

    private func advance() {
        isFlipped = false
        if index + 1 < cards.count {
            index += 1
        } else {
            state = .finished(reviewed: cards.count)
        }
    }
}
