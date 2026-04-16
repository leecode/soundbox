import XCTest
@testable import SoundBox

final class VTTParserTests: XCTestCase {

    // MARK: - Basic Parsing

    func testParseSimpleVTT() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        Hello World

        00:00:05.000 --> 00:00:08.000
        Second cue
        """

        let cues = VTTParser.parse(from: content)
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[0].text, "Hello World")
        XCTAssertEqual(cues[0].startTime, 1.0)
        XCTAssertEqual(cues[0].endTime, 3.0)
        XCTAssertEqual(cues[1].text, "Second cue")
        XCTAssertEqual(cues[1].startTime, 5.0)
        XCTAssertEqual(cues[1].endTime, 8.0)
    }

    func testParseShortTimeFormat() {
        let content = """
        WEBVTT

        00:01.000 --> 00:05.000
        Short format
        """

        let cues = VTTParser.parse(from: content)
        XCTAssertEqual(cues.count, 1)
        XCTAssertEqual(cues[0].startTime, 1.0)
        XCTAssertEqual(cues[0].endTime, 5.0)
    }

    func testParseMultilineCue() {
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        Line one
        Line two
        """

        let cues = VTTParser.parse(from: content)
        XCTAssertEqual(cues.count, 1)
        XCTAssertEqual(cues[0].text, "Line one\nLine two")
    }

    func testParseEmptyContent() {
        let cues = VTTParser.parse(from: "")
        XCTAssertEqual(cues.count, 0)
    }

    func testParseHeaderOnly() {
        let cues = VTTParser.parse(from: "WEBVTT\n\n")
        XCTAssertEqual(cues.count, 0)
    }

    // MARK: - Time Parsing

    func testHourMinuteSecondFormat() {
        let content = """
        WEBVTT

        01:30:45.000 --> 01:30:50.000
        Long track
        """

        let cues = VTTParser.parse(from: content)
        XCTAssertEqual(cues[0].startTime, 1 * 3600 + 30 * 60 + 45)
    }

    // MARK: - Subtitle Manager

    func testSubtitleManagerUpdate() {
        let manager = SubtitleManager()
        let content = """
        WEBVTT

        00:00:01.000 --> 00:00:03.000
        First

        00:00:05.000 --> 00:00:08.000
        Second
        """

        // Can't directly set cues, use load from a temp file
        // Instead test update behavior with manually set cues
        manager.cues = VTTParser.parse(from: content)
        XCTAssertEqual(manager.cues.count, 2)

        manager.update(for: 2.0)
        XCTAssertEqual(manager.currentCue?.text, "First")

        manager.update(for: 6.0)
        XCTAssertEqual(manager.currentCue?.text, "Second")

        manager.update(for: 4.0)
        XCTAssertNil(manager.currentCue)
    }
}
