import Foundation

struct DashboardResponse: Decodable, Equatable {
    let track: Track
    let streak: Int
    let dueWords: Int
    let activeMistakes: Int
    let isNewUser: Bool
    let inProgressExamId: String?
    let lastExamEstimate: ExamEstimate?
    let recentScores: [RecentScore]
}

/// Server may grow new score kinds; unknown values must not fail dashboard decoding.
enum ScoreKind: Equatable, Hashable {
    case reading
    case listening
    case vocabQuiz
    case writing
    case speaking
    case exam
    case unknown(String)

    var displayName: String {
        switch self {
        case .reading: String(localized: "Reading")
        case .listening: String(localized: "Listening")
        case .vocabQuiz: String(localized: "Vocabulary Quiz")
        case .writing: String(localized: "Writing")
        case .speaking: String(localized: "Speaking")
        case .exam: String(localized: "Mock Exam")
        case .unknown(let raw): raw.capitalized
        }
    }
}

extension ScoreKind: Decodable {
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "reading": self = .reading
        case "listening": self = .listening
        case "vocab_quiz": self = .vocabQuiz
        case "writing": self = .writing
        case "speaking": self = .speaking
        case "exam": self = .exam
        default: self = .unknown(raw)
        }
    }
}

/// Entries are heterogeneous by `kind`: exercises carry score/total, writing and
/// speaking carry an optional scoreLabel, exams carry an estimate.
struct RecentScore: Decodable, Equatable, Identifiable {
    let kind: ScoreKind
    let at: Date
    let score: Int?
    let total: Int?
    let scoreLabel: String?
    let estimate: ExamEstimate?

    var id: String { "\(kind.displayName)-\(at.timeIntervalSince1970)" }
}

enum ExamEstimate: Equatable {
    case toeic(listening: Int, reading: Int, total: Int)
    case ielts(band: Double)

    var displayText: String {
        switch self {
        case .toeic(_, _, let total): String(localized: "TOEIC \(total)")
        case .ielts(let band): String(localized: "IELTS \(band.formatted(.number.precision(.fractionLength(0...1))))")
        }
    }
}

extension ExamEstimate: Decodable {
    private enum CodingKeys: String, CodingKey {
        case kind, listening, reading, total, band
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "toeic":
            self = .toeic(
                listening: try container.decode(Int.self, forKey: .listening),
                reading: try container.decode(Int.self, forKey: .reading),
                total: try container.decode(Int.self, forKey: .total)
            )
        case "ielts":
            self = .ielts(band: try container.decode(Double.self, forKey: .band))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: container,
                debugDescription: "Unknown exam estimate kind: \(kind)"
            )
        }
    }
}
