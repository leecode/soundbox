import Foundation
import os.log

// MARK: - Audio Format
struct AudioFormat: Equatable {
    var sampleRate: Double
    var bitDepth: Int
    var channels: Int
    var isFloat: Bool
    var isBigEndian: Bool

    static let cdQuality = AudioFormat(sampleRate: 44100, bitDepth: 16, channels: 2, isFloat: false, isBigEndian: false)
    static let hiRes96 = AudioFormat(sampleRate: 96000, bitDepth: 24, channels: 2, isFloat: false, isBigEndian: false)
    static let hiRes192 = AudioFormat(sampleRate: 192000, bitDepth: 24, channels: 2, isFloat: false, isBigEndian: false)

    var description: String {
        let rateStr = sampleRate >= 1000 ? "\(Int(sampleRate/1000))kHz" : "\(Int(sampleRate))Hz"
        let bitStr = isFloat ? "\(bitDepth)bit float" : "\(bitDepth)bit"
        return "\(rateStr) / \(bitStr) / \(channels == 1 ? "Mono" : "Stereo")"
    }

    var isHiRes: Bool {
        return sampleRate >= 96000 || bitDepth >= 24
    }
}

// MARK: - Audio File
struct AudioFile: Identifiable, Hashable {
    let id = UUID()
    private static let logger = Logger(subsystem: "com.soundbox", category: "AudioFile")
    let url: URL
    let name: String
    let format: AudioFormat
    let duration: TimeInterval
    let fileSize: UInt64
    let subtitleURL: URL?
    let artworkURL: URL?
    let scriptURL: URL?
    let embeddedTitle: String?
    let embeddedArtist: String?
    let embeddedAlbum: String?
    let embeddedArtworkData: Data?

    init(url: URL, format: AudioFormat = .cdQuality, duration: TimeInterval = 0, subtitleURL: URL? = nil, artworkURL: URL? = nil, scriptURL: URL? = nil, embeddedTitle: String? = nil, embeddedArtist: String? = nil, embeddedAlbum: String? = nil, embeddedArtworkData: Data? = nil) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.format = format
        self.duration = duration
        let fileSize: UInt64
        do {
            fileSize = UInt64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        } catch {
            AudioFile.logger.error("Failed to read file size for \(url.lastPathComponent): \(error.localizedDescription)")
            fileSize = 0
        }
        self.fileSize = fileSize
        self.subtitleURL = subtitleURL
        self.artworkURL = artworkURL
        self.scriptURL = scriptURL
        self.embeddedTitle = embeddedTitle
        self.embeddedArtist = embeddedArtist
        self.embeddedAlbum = embeddedAlbum
        self.embeddedArtworkData = embeddedArtworkData
    }

    // Explicit Hashable conformance - hash by URL only
    static func == (lhs: AudioFile, rhs: AudioFile) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    var formattedDuration: String {
        FormatUtils.formatTime(duration)
    }

    var formattedSize: String {
        let mb = Double(fileSize) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Track
struct Track: Identifiable, Hashable {
    let id = UUID()
    let audioFile: AudioFile
    var index: Int
    var title: String
    var artist: String?
    var album: String?

    init(audioFile: AudioFile, index: Int = 0, title: String? = nil, artist: String? = nil, album: String? = nil) {
        self.audioFile = audioFile
        self.index = index
        self.title = title ?? audioFile.name
        self.artist = artist
        self.album = album
    }
}

// MARK: - Playlist
class Playlist: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var currentIndex: Int = 0
    @Published var repeatMode: RepeatMode = .none
    @Published var isShuffled: Bool = false

    enum RepeatMode {
        case none
        case one
        case all
    }

    var currentTrack: Track? {
        guard tracks.indices.contains(currentIndex) else { return nil }
        return tracks[currentIndex]
    }

    var nextTrack: Track? {
        guard !tracks.isEmpty else { return nil }
        let nextIndex = currentIndex + 1
        if nextIndex < tracks.count {
            return tracks[nextIndex]
        } else if repeatMode == .all {
            return tracks[0]
        }
        return nil
    }

    var previousTrack: Track? {
        guard !tracks.isEmpty else { return nil }
        let prevIndex = currentIndex - 1
        if prevIndex >= 0 {
            return tracks[prevIndex]
        } else if repeatMode == .all {
            return tracks[tracks.count - 1]
        }
        return nil
    }

    func addTrack(_ track: Track) {
        tracks.append(track)
    }

    func addTracks(_ newTracks: [Track]) {
        let existingURLs = Set(tracks.map { $0.audioFile.url })
        let uniqueTracks = newTracks.filter { !existingURLs.contains($0.audioFile.url) }
        tracks.append(contentsOf: uniqueTracks)
    }

    func removeTrack(at index: Int) {
        guard tracks.indices.contains(index) else { return }
        tracks.remove(at: index)
        if currentIndex >= tracks.count {
            currentIndex = max(0, tracks.count - 1)
        }
    }

    func clear() {
        tracks.removeAll()
        currentIndex = 0
    }

    func selectTrack(at index: Int) {
        guard tracks.indices.contains(index) else { return }
        currentIndex = index
    }
}

// MARK: - Player State
class PlayerState: ObservableObject {
    @Published var playbackState: PlaybackState = .stopped
    @Published var currentTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var volume: Float = 1.0
    @Published var playbackRate: Float = 1.0
    @Published var currentSubtitle: String?

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return currentTime / totalDuration
    }
}

// MARK: - A-B Repeat
struct ABRepeatRange: Equatable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let source: ABRepeatSource

    var duration: TimeInterval {
        endTime - startTime
    }
}

enum ABRepeatSource: Equatable {
    case manual
    case subtitle
}

// MARK: - Playback State
enum PlaybackState: Equatable {
    case stopped
    case playing
    case paused
    case loading
    case finished  // 播放完成（非用户手动停止）
    case error(String)

    var isPlaying: Bool {
        return self == .playing
    }
}

// MARK: - Subtitle Preview Item
struct SubtitlePreviewItem: Identifiable {
    let id: String           // "trackIndex-cueId"
    let trackIndex: Int
    let trackTitle: String
    let cue: VTTParser.SubtitleCue
}

// MARK: - Folder History Item
struct FolderHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let url: URL
    let name: String
    let lastOpenedAt: Date

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.lastOpenedAt = Date()
    }

    static func == (lhs: FolderHistoryItem, rhs: FolderHistoryItem) -> Bool {
        lhs.url == rhs.url
    }
}

// MARK: - Folder History Manager
class FolderHistoryManager: ObservableObject {
    @Published var items: [FolderHistoryItem] = []

    private let maxItems = 10
    private let userDefaultsKey = "folderHistory"
    private static let logger = Logger(subsystem: "com.soundbox", category: "FolderHistory")

    init() {
        load()
    }

    func add(_ url: URL) {
        // 移除已存在的相同路径
        items.removeAll { $0.url == url }

        // 添加到开头
        let newItem = FolderHistoryItem(url: url)
        items.insert(newItem, at: 0)

        // 限制数量
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        save()
    }

    func remove(_ item: FolderHistoryItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    func itemExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            Self.logger.error("Failed to save folder history: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            items = try JSONDecoder().decode([FolderHistoryItem].self, from: data)
        } catch {
            Self.logger.error("Failed to load folder history: \(error.localizedDescription)")
        }
    }
}

// MARK: - Playback Position
struct PlaybackPosition: Codable {
    let url: URL
    let position: TimeInterval
    let duration: TimeInterval
    let updatedAt: Date
}

// MARK: - Playback Position Manager
class PlaybackPositionManager {
    private var positions: [String: PlaybackPosition] = [:]
    private let maxPositions = 200
    private let userDefaultsKey = "playbackPositions"
    private static let lastPlayingURLKey = "lastPlayingTrackURL"
    private static let logger = Logger(subsystem: "com.soundbox", category: "PlaybackPosition")

    // One-shot restore: set from saved URL on init, cleared after first use
    private var restoreURL: URL?

    init() {
        load()
        restoreURL = UserDefaults.standard.url(forKey: Self.lastPlayingURLKey)
    }

    func savePosition(for url: URL, position: TimeInterval, duration: TimeInterval) {
        // Near end of track: treat as finished, remove position
        if duration > 5 && (duration - position) < 5.0 {
            removePosition(for: url)
            return
        }

        let key = url.absoluteString
        positions[key] = PlaybackPosition(
            url: url,
            position: position,
            duration: duration,
            updatedAt: Date()
        )

        // Trim oldest if over limit
        if positions.count > maxPositions {
            let sorted = positions.values.sorted { $0.updatedAt < $1.updatedAt }
            for item in sorted.prefix(positions.count - maxPositions) {
                positions.removeValue(forKey: item.url.absoluteString)
            }
        }

        save()
        markLastPlaying(url)
    }

    /// Returns saved position if the URL matches the app-launch restore target.
    /// Clears after one call so manual track changes start from the beginning.
    func restorePositionIfNeeded(for url: URL, currentDuration: TimeInterval = 0) -> TimeInterval? {
        guard url == restoreURL,
              let saved = positions[url.absoluteString] else {
            return nil
        }
        restoreURL = nil
        // If we have a current duration, discard if file changed significantly
        if currentDuration > 0 && abs(saved.duration - currentDuration) > 1.0 {
            return nil
        }
        return saved.position
    }

    func removePosition(for url: URL) {
        positions.removeValue(forKey: url.absoluteString)
        save()
    }

    func markLastPlaying(_ url: URL) {
        UserDefaults.standard.set(url, forKey: Self.lastPlayingURLKey)
    }

    private func save() {
        let array = Array(positions.values)
        do {
            let data = try JSONEncoder().encode(array)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            Self.logger.error("Failed to save playback positions: \(error.localizedDescription)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([PlaybackPosition].self, from: data)
            for pos in decoded {
                positions[pos.url.absoluteString] = pos
            }
        } catch {
            Self.logger.error("Failed to load playback positions: \(error.localizedDescription)")
        }
    }
}
