import Foundation

enum Track: String, Codable, CaseIterable, Identifiable, Hashable {
    case toeic
    case ielts
    case business

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toeic: "TOEIC"
        case .ielts: "IELTS"
        case .business: "Business English"
        }
    }
}
