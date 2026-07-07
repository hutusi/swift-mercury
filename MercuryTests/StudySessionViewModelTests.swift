import Foundation
import Testing

@testable import Mercury

struct StudySessionViewModelTests {
    @Test func loadWithCardsEntersStudying() async {
        let api = MockAPI()
        api.studyQueueHandler = { [.fixture(id: "w1"), .fixture(id: "w2", isNew: false)] }
        let model = StudySessionViewModel(api: api)

        await model.load()

        #expect(model.state == .studying)
        #expect(model.currentCard?.wordId == "w1")
        #expect(model.progressText == "1 / 2")
    }

    @Test func loadWithEmptyQueueIsEmpty() async {
        let api = MockAPI()
        api.studyQueueHandler = { [] }
        let model = StudySessionViewModel(api: api)

        await model.load()

        #expect(model.state == .empty)
    }

    @Test func gradeSendsServerValueAndAdvances() async {
        let api = MockAPI()
        api.studyQueueHandler = { [.fixture(id: "w1"), .fixture(id: "w2")] }
        var graded: [(String, Grade)] = []
        api.gradeHandler = { wordId, grade in
            graded.append((wordId, grade))
            return 1
        }
        let model = StudySessionViewModel(api: api)
        await model.load()
        model.flip()

        await model.grade(.good)

        #expect(graded.count == 1)
        #expect(graded[0].0 == "w1")
        #expect(graded[0].1 == .good)
        #expect(model.currentCard?.wordId == "w2")
        #expect(!model.isFlipped)
        #expect(model.state == .studying)
    }

    @Test func gradingLastCardFinishesSession() async {
        let api = MockAPI()
        api.studyQueueHandler = { [.fixture(id: "w1")] }
        api.gradeHandler = { _, _ in 3 }
        let model = StudySessionViewModel(api: api)
        await model.load()

        await model.grade(.easy)

        #expect(model.state == .finished(reviewed: 1))
    }

    @Test func gradeFailureKeepsCardForRetry() async {
        let api = MockAPI()
        api.studyQueueHandler = { [.fixture(id: "w1"), .fixture(id: "w2")] }
        var attempts = 0
        api.gradeHandler = { _, _ in
            attempts += 1
            if attempts == 1 {
                throw APIError.transport(underlying: URLError(.timedOut))
            }
            return 1
        }
        let model = StudySessionViewModel(api: api)
        await model.load()
        model.flip()

        await model.grade(.again)

        #expect(model.gradeError != nil)
        #expect(model.currentCard?.wordId == "w1")
        #expect(model.isFlipped)

        await model.grade(.again)

        #expect(model.gradeError == nil)
        #expect(model.currentCard?.wordId == "w2")
    }

    @Test func sm2GradeValuesMatchServerContract() {
        #expect(Grade.again.rawValue == 1)
        #expect(Grade.hard.rawValue == 3)
        #expect(Grade.good.rawValue == 4)
        #expect(Grade.easy.rawValue == 5)
    }
}
