import XCTest
@testable import SoundBox

final class BookmarkManagerTests: XCTestCase {

    private var manager: BookmarkManager!

    override func setUp() {
        super.setUp()
        manager = BookmarkManager()
        // Clear all existing bookmarks for test isolation
        manager.bookmarks.removeAll()
    }

    override func tearDown() {
        manager.bookmarks.removeAll()
        super.tearDown()
    }

    // MARK: - Add Bookmark

    func testAddBookmark() {
        let url = URL(fileURLWithPath: "/test/audio.wav")
        manager.addBookmark(audioFileURL: url, timestamp: 30.0, label: "Test")

        XCTAssertEqual(manager.bookmarks.count, 1)
        XCTAssertEqual(manager.bookmarks[0].audioFileURL, url)
        XCTAssertEqual(manager.bookmarks[0].timestamp, 30.0)
        XCTAssertEqual(manager.bookmarks[0].label, "Test")
    }

    func testAddBookmarkEmptyLabel() {
        let url = URL(fileURLWithPath: "/test/audio.wav")
        manager.addBookmark(audioFileURL: url, timestamp: 10.0)

        XCTAssertEqual(manager.bookmarks[0].label, "")
    }

    // MARK: - Remove Bookmark

    func testRemoveBookmark() {
        let url = URL(fileURLWithPath: "/test/audio.wav")
        manager.addBookmark(audioFileURL: url, timestamp: 10.0, label: "A")
        manager.addBookmark(audioFileURL: url, timestamp: 20.0, label: "B")

        let toRemove = manager.bookmarks[0]
        manager.removeBookmark(toRemove)

        XCTAssertEqual(manager.bookmarks.count, 1)
        XCTAssertEqual(manager.bookmarks[0].label, "B")
    }

    // MARK: - Bookmarks for URL

    func testBookmarksForURL() {
        let url1 = URL(fileURLWithPath: "/test/audio1.wav")
        let url2 = URL(fileURLWithPath: "/test/audio2.wav")

        manager.addBookmark(audioFileURL: url1, timestamp: 10.0)
        manager.addBookmark(audioFileURL: url2, timestamp: 20.0)
        manager.addBookmark(audioFileURL: url1, timestamp: 30.0)

        let bookmarks1 = manager.bookmarks(for: url1)
        XCTAssertEqual(bookmarks1.count, 2)
        // Should be sorted by timestamp
        XCTAssertEqual(bookmarks1[0].timestamp, 10.0)
        XCTAssertEqual(bookmarks1[1].timestamp, 30.0)

        let bookmarks2 = manager.bookmarks(for: url2)
        XCTAssertEqual(bookmarks2.count, 1)
    }

    // MARK: - Persistence

    func testPersistence() {
        let url = URL(fileURLWithPath: "/test/audio.wav")
        manager.addBookmark(audioFileURL: url, timestamp: 42.0, label: "Persist")

        // Create new manager, should load from UserDefaults
        let manager2 = BookmarkManager()
        XCTAssertEqual(manager2.bookmarks.count, 1)
        XCTAssertEqual(manager2.bookmarks[0].timestamp, 42.0)
        XCTAssertEqual(manager2.bookmarks[0].label, "Persist")

        // Clean up
        manager2.bookmarks.removeAll()
    }

    // MARK: - Trim

    func testTrimWhenOverLimit() {
        let url = URL(fileURLWithPath: "/test/audio.wav")
        // Add 502 bookmarks (limit is 500)
        for i in 0..<502 {
            manager.addBookmark(audioFileURL: url, timestamp: Double(i), label: "BM\(i)")
        }

        XCTAssertEqual(manager.bookmarks.count, 500)
    }
}
