import Foundation

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
    let url: URL
    let name: String
    let format: AudioFormat
    let duration: TimeInterval
    let fileSize: UInt64
    let subtitleURL: URL?

    init(url: URL, format: AudioFormat = .cdQuality, duration: TimeInterval = 0, subtitleURL: URL? = nil) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.format = format
        self.duration = duration
        self.fileSize = UInt64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        self.subtitleURL = subtitleURL
    }

    // Explicit Hashable conformance - hash by URL only
    static func == (lhs: AudioFile, rhs: AudioFile) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
        print("🎵 Playlist.addTracks 被调用，添加 \(newTracks.count) 个曲目")
        print("🎵 添加前 tracks.count = \(tracks.count)")
        tracks.append(contentsOf: newTracks)
        print("🎵 添加后 tracks.count = \(tracks.count)")
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
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([FolderHistoryItem].self, from: data) else {
            return
        }
        items = decoded
    }
}
