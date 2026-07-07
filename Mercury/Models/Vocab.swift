import Foundation

struct VocabWord: Decodable, Equatable, Identifiable {
    let id: String
    let track: Track
    let topic: String
    let headword: String
    let ipa: String
    let pos: String
    let definitionEn: String
    let translationZh: String
    let exampleEn: String
    let exampleZh: String

    init(
        id: String, track: Track, topic: String, headword: String, ipa: String,
        pos: String, definitionEn: String, translationZh: String,
        exampleEn: String, exampleZh: String
    ) {
        self.id = id
        self.track = track
        self.topic = topic
        self.headword = headword
        self.ipa = ipa
        self.pos = pos
        self.definitionEn = definitionEn
        self.translationZh = translationZh
        self.exampleEn = exampleEn
        self.exampleZh = exampleZh
    }
}

/// A vocab word plus the caller's SRS flags, flattened in the JSON.
struct OverviewWord: Decodable, Equatable, Identifiable {
    let word: VocabWord
    let started: Bool
    let due: Bool

    var id: String { word.id }

    init(word: VocabWord, started: Bool, due: Bool) {
        self.word = word
        self.started = started
        self.due = due
    }

    private enum CodingKeys: String, CodingKey {
        case started, due
    }

    init(from decoder: any Decoder) throws {
        word = try VocabWord(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        started = try container.decode(Bool.self, forKey: .started)
        due = try container.decode(Bool.self, forKey: .due)
    }
}

struct VocabOverview: Decodable, Equatable {
    let words: [OverviewWord]
    let dueCount: Int
    let freshCount: Int
    let learnedCount: Int
}

struct StudyCard: Decodable, Equatable, Identifiable {
    let word: VocabWord
    let wordId: String
    let isNew: Bool

    var id: String { wordId }

    init(word: VocabWord, wordId: String, isNew: Bool) {
        self.word = word
        self.wordId = wordId
        self.isNew = isNew
    }

    private enum CodingKeys: String, CodingKey {
        case wordId, isNew
    }

    init(from decoder: any Decoder) throws {
        word = try VocabWord(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wordId = try container.decode(String.self, forKey: .wordId)
        isNew = try container.decode(Bool.self, forKey: .isNew)
    }
}

struct StudyQueue: Decodable, Equatable {
    let cards: [StudyCard]
}

/// SM-2 self-assessment values; the server accepts exactly 1, 3, 4, 5.
enum Grade: Int, CaseIterable {
    case again = 1
    case hard = 3
    case good = 4
    case easy = 5

    var displayName: String {
        switch self {
        case .again: String(localized: "Again")
        case .hard: String(localized: "Hard")
        case .good: String(localized: "Good")
        case .easy: String(localized: "Easy")
        }
    }
}

struct GradeResponse: Decodable, Equatable {
    let intervalDays: Int
}

enum QuizDirection: String, Decodable, Equatable {
    case en2zh
    case zh2en
}

struct QuizOption: Decodable, Equatable, Identifiable {
    let wordId: String
    let text: String

    var id: String { wordId }

    init(wordId: String, text: String) {
        self.wordId = wordId
        self.text = text
    }
}

struct QuizQuestion: Decodable, Equatable, Identifiable {
    let wordId: String
    let direction: QuizDirection
    let prompt: String
    let options: [QuizOption]

    var id: String { wordId }

    init(wordId: String, direction: QuizDirection, prompt: String, options: [QuizOption]) {
        self.wordId = wordId
        self.direction = direction
        self.prompt = prompt
        self.options = options
    }
}

struct QuizResponse: Decodable, Equatable {
    let track: Track
    let questions: [QuizQuestion]
}

struct QuizResult: Decodable, Equatable {
    let score: Int
    let total: Int
    let correctWordIds: [String]
}
