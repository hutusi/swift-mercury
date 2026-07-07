import Foundation

enum Track: String, Codable, CaseIterable, Identifiable, Hashable {
    case toeic
    case ielts
    case business

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toeic: String(localized: "TOEIC")
        case .ielts: String(localized: "IELTS")
        case .business: String(localized: "Business English")
        }
    }
}
