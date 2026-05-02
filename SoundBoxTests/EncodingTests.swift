import XCTest
@testable import SoundBox

final class EncodingTests: XCTestCase {

    // MARK: - Shift-JIS Detection

    func testShiftJISEncodingDetection() {
        // Common Japanese text in Shift-JIS: "こんにちは" (Hello)
        let japaneseText = "こんにちは世界"
        let shiftJISEncoding = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.shiftJIS.rawValue))
        )
        guard let shiftJISData = japaneseText.data(using: shiftJISEncoding) else {
            XCTFail("Failed to encode test string as Shift-JIS")
            return
        }

        // Write to temp file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_shiftjis_\(UUID().uuidString).txt")
        try? shiftJISData.write(to: tempFile)

        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }

        // Test reading with the same fallback shape used by AppState.loadScript.
        var usedEncoding: UInt = 0
        let content = (try? NSString(contentsOf: tempFile, usedEncoding: &usedEncoding) as String)
            ?? (try? String(contentsOf: tempFile, encoding: .utf8))
            ?? (try? String(contentsOf: tempFile, encoding: shiftJISEncoding))
            ?? (try? String(contentsOf: tempFile, encoding: .ascii))
        XCTAssertNotNil(content)
        XCTAssertEqual(content, japaneseText)
    }

    func testUTF8EncodingDetection() {
        let text = "これはテストです"  // Japanese UTF-8 text
        guard let data = text.data(using: .utf8) else {
            XCTFail("Failed to encode test string as UTF-8")
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_utf8_\(UUID().uuidString).txt")
        try? data.write(to: tempFile)

        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }

        var usedEncoding: UInt = 0
        let content = try? NSString(contentsOf: tempFile, usedEncoding: &usedEncoding) as String
        XCTAssertNotNil(content)
        XCTAssertEqual(content, text)
    }

    func testFallbackChain() {
        // Plain ASCII text should work with any encoding
        let text = "Hello World"
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_ascii_\(UUID().uuidString).txt")
        try? text.data(using: .ascii)?.write(to: tempFile)

        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }

        var usedEncoding: UInt = 0
        let content = try? NSString(contentsOf: tempFile, usedEncoding: &usedEncoding) as String
        XCTAssertNotNil(content)
        XCTAssertEqual(content, text)
    }
}
