import Foundation

enum SidePanelTab: Int, CaseIterable, Hashable, Identifiable {
    case subtitles = 0
    case script = 1
    case bookmarks = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .subtitles: return "字幕"
        case .script: return "台本"
        case .bookmarks: return "书签"
        }
    }

    var iconName: String {
        switch self {
        case .subtitles: return "text.bubble"
        case .script: return "doc.text"
        case .bookmarks: return "bookmark"
        }
    }
}
