import Foundation

// MARK: - Bookmark
struct Bookmark: Identifiable, Codable, Equatable {
    let id: UUID
    let audioFileURL: URL
    let timestamp: TimeInterval
    let label: String
    let createdAt: Date

    init(id: UUID = UUID(), audioFileURL: URL, timestamp: TimeInterval, label: String = "", createdAt: Date = Date()) {
        self.id = id
        self.audioFileURL = audioFileURL
        self.timestamp = timestamp
        self.label = label
        self.createdAt = createdAt
    }

    static func == (lhs: Bookmark, rhs: Bookmark) -> Bool {
        lhs.id == rhs.id
    }
}
