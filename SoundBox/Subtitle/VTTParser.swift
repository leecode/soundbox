import Foundation

// MARK: - VTT Subtitle Parser
class VTTParser {

    // MARK: - Parse Result
    struct SubtitleCue: Identifiable {
        let id: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let text: String
    }

    // MARK: - Parse
    static func parse(from url: URL) -> [SubtitleCue] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return parse(from: content)
    }

    static func parse(from content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let lines = content.components(separatedBy: .newlines)

        var i = 0
        var cueId = 0

        // 跳过 WEBVTT 头部
        while i < lines.count && !lines[i].contains("-->") {
            i += 1
        }

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            // 查找时间线
            if line.contains("-->") {
                let timeComponents = line.components(separatedBy: "-->")
                guard timeComponents.count == 2 else {
                    i += 1
                    continue
                }

                let startTime = parseTime(timeComponents[0].trimmingCharacters(in: .whitespaces))
                let endTime = parseTime(timeComponents[1].trimmingCharacters(in: .whitespaces))

                // 收集字幕文本
                i += 1
                var textLines: [String] = []
                while i < lines.count && !lines[i].isEmpty && !lines[i].contains("-->") {
                    textLines.append(lines[i].trimmingCharacters(in: .whitespaces))
                    i += 1
                }

                let text = textLines.joined(separator: "\n")

                if !text.isEmpty {
                    cues.append(SubtitleCue(
                        id: String(cueId),
                        startTime: startTime,
                        endTime: endTime,
                        text: text
                    ))
                    cueId += 1
                }
            } else {
                i += 1
            }
        }

        return cues
    }

    // MARK: - Time Parser
    private static func parseTime(_ timeString: String) -> TimeInterval {
        // VTT 格式: 00:00:00.000 或 00:00.000
        var hours: Double = 0
        var minutes: Double = 0
        var seconds: Double = 0

        // 移除可能的位置参数 (如 00:00:00.000 position:50%)
        let cleanTime = timeString.components(separatedBy: .whitespaces).first ?? timeString

        let components = cleanTime.components(separatedBy: ":")

        if components.count == 3 {
            hours = Double(components[0]) ?? 0
            minutes = Double(components[1]) ?? 0
            seconds = Double(components[2]) ?? 0
        } else if components.count == 2 {
            minutes = Double(components[0]) ?? 0
            seconds = Double(components[1]) ?? 0
        }

        return hours * 3600 + minutes * 60 + seconds
    }
}

// MARK: - Subtitle Manager
class SubtitleManager: ObservableObject {
    @Published var cues: [VTTParser.SubtitleCue] = []
    @Published var currentCue: VTTParser.SubtitleCue?

    private var currentIndex = 0

    func load(from url: URL) {
        print("📝 SubtitleManager.load 被调用: \(url.path)")
        cues = VTTParser.parse(from: url)
        currentIndex = 0
        currentCue = nil
        print("📝 解析到 \(cues.count) 条字幕")
        if let first = cues.first {
            print("📝 第一条: [\(first.startTime)-\(first.endTime)] \(first.text)")
        }
    }

    func update(for time: TimeInterval) {
        // 如果当前时间在索引之前（seek 或重新播放），重置索引从头搜索
        if currentIndex > 0, let firstCue = cues.first, time < firstCue.startTime {
            // 时间在所有字幕之前，清除当前字幕
            if currentCue != nil {
                currentCue = nil
            }
            currentIndex = 0
            return
        }

        if currentIndex > 0 && time < cues[currentIndex].startTime {
            // 时间回退了，从头开始搜索
            currentIndex = 0
        }

        // 找到当前时间对应的字幕
        while currentIndex < cues.count {
            let cue = cues[currentIndex]

            if time >= cue.startTime && time <= cue.endTime {
                if currentCue?.id != cue.id {
                    currentCue = cue
                }
                return
            } else if time > cue.endTime {
                currentIndex += 1
            } else {
                // time < cue.startTime，当前时间在字幕开始之前
                break
            }
        }

        // 当前时间没有对应字幕，清除
        if currentCue != nil {
            currentCue = nil
        }
    }

    func reset() {
        currentIndex = 0
        currentCue = nil
    }
}
