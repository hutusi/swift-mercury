import Foundation

struct UserProfile: Decodable, Equatable {
    let id: String
    let name: String
    let email: String
}

struct UserSettings: Decodable, Equatable {
    let activeTrack: Track
    let dailyGoal: Int
    let onboardedAt: Date
}

struct MeResponse: Decodable, Equatable {
    let user: UserProfile
    let settings: UserSettings?
    let aiEnabled: Bool
}

struct SettingsResponse: Decodable, Equatable {
    let settings: UserSettings
}
