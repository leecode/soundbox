import Foundation
import Combine

// MARK: - Bookmark Manager
class BookmarkManager: ObservableObject {
    @Published var bookmarks: [Bookmark] = []

    private let maxBookmarks = 500
    private let userDefaultsKey = "bookmarks"
    private let schemaVersionKey = "bookmarksSchemaVersion"
    private let currentSchemaVersion = 1

    init() {
        load()
    }

    // MARK: - CRUD

    func addBookmark(audioFileURL: URL, timestamp: TimeInterval, label: String = "") {
        let bookmark = Bookmark(audioFileURL: audioFileURL, timestamp: timestamp, label: label)
        bookmarks.append(bookmark)
        trimIfNeeded()
        save()
    }

    func removeBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    func removeBookmark(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        save()
    }

    /// All bookmarks for a specific audio file
    func bookmarks(for url: URL) -> [Bookmark] {
        bookmarks.filter { $0.audioFileURL == url }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Persistence

    private func load() {
        let savedVersion = UserDefaults.standard.integer(forKey: schemaVersionKey)
        guard savedVersion == currentSchemaVersion else {
            // Schema mismatch or first launch: start fresh
            UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)
            return
        }

        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) else {
            return
        }
        bookmarks = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func trimIfNeeded() {
        if bookmarks.count > maxBookmarks {
            let sorted = bookmarks.sorted { $0.createdAt < $1.createdAt }
            let toRemove = sorted.prefix(bookmarks.count - maxBookmarks)
            let removeIds = Set(toRemove.map { $0.id })
            bookmarks.removeAll { removeIds.contains($0.id) }
        }
    }
}
