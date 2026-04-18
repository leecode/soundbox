import Foundation
import Combine
import os.log

// MARK: - Bookmark Manager
class BookmarkManager: ObservableObject {
    @Published var bookmarks: [Bookmark] = []

    private static let logger = Logger(subsystem: "com.soundbox", category: "BookmarkManager")

    private let maxBookmarks = 500
    private let currentSchemaVersion = 1

    private let storageDirectory: URL
    private let bookmarksFile: URL
    private let versionFile: URL

    init() {
        // ~/Library/Application Support/SoundBox/
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDirectory = appSupport.appendingPathComponent("SoundBox", isDirectory: true)
        bookmarksFile = storageDirectory.appendingPathComponent("bookmarks.json")
        versionFile = storageDirectory.appendingPathComponent("bookmarks.version")

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
        let fm = FileManager.default

        // Ensure directory exists
        do {
            if !fm.fileExists(atPath: storageDirectory.path) {
                try fm.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            }
        } catch {
            Self.logger.error("Failed to create storage directory: \(error.localizedDescription)")
        }

        // Check schema version
        let savedVersion = (try? String(contentsOf: versionFile, encoding: .utf8)).flatMap(Int.init) ?? 0
        guard savedVersion == currentSchemaVersion else {
            // Schema mismatch or first launch: write version, start fresh
            try? "\(currentSchemaVersion)".write(to: versionFile, atomically: true, encoding: .utf8)
            return
        }

        guard fm.fileExists(atPath: bookmarksFile.path) else { return }

        do {
            let data = try Data(contentsOf: bookmarksFile)
            bookmarks = try JSONDecoder().decode([Bookmark].self, from: data)
        } catch {
            Self.logger.error("Failed to load bookmarks: \(error.localizedDescription)")
        }
    }

    private func save() {
        let fm = FileManager.default

        // Ensure directory exists
        do {
            if !fm.fileExists(atPath: storageDirectory.path) {
                try fm.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            }
        } catch {
            Self.logger.error("Failed to create storage directory: \(error.localizedDescription)")
            return
        }

        let data: Data
        do {
            data = try JSONEncoder().encode(bookmarks)
        } catch {
            Self.logger.error("Failed to encode bookmarks: \(error.localizedDescription)")
            return
        }

        do {
            try data.write(to: bookmarksFile, options: .atomic)
        } catch {
            Self.logger.error("Failed to save bookmarks: \(error.localizedDescription)")
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
