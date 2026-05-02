import Foundation

struct CompanionPlaybackState: Codable {
    let trackTitle: String
    let artist: String?
    let playbackState: String
    let currentTime: TimeInterval
    let duration: TimeInterval
    let playbackRate: Float
    let currentSubtitle: String?
    let subtitles: [CompanionSubtitleCue]
}

struct CompanionSubtitleCue: Codable {
    let id: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let isActive: Bool
}

struct CompanionCommand: Decodable {
    let name: String
    let time: TimeInterval?
    let rate: Float?
    let label: String?
}
