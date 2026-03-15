import SwiftUI
import Combine

@main
struct SoundBoxApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // 替换新建菜单为打开文件夹
            CommandGroup(replacing: .newItem) {
                Button("打开文件夹...") {
                    openFolderPicker()
                }
                .keyboardShortcut("o", modifiers: .command)

                // 最近打开的文件夹
                if !appState.folderHistoryManager.items.isEmpty {
                    Divider()

                    Menu("最近打开") {
                        ForEach(appState.folderHistoryManager.items) { item in
                            Button(item.name) {
                                openFolderFromHistory(item)
                            }
                        }

                        Divider()

                        Button("清除历史") {
                            appState.folderHistoryManager.clear()
                        }
                    }
                }
            }

            // 播放控制菜单
            CommandMenu("播放") {
                Button("播放/暂停") {
                    togglePlayback()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("上一曲") {
                    previousTrack()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Button("下一曲") {
                    nextTrack()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Divider()

                Button("快退5秒") {
                    seekBackward()
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button("快进5秒") {
                    seekForward()
                }
                .keyboardShortcut(.rightArrow, modifiers: [])

                Divider()

                Button("循环模式") {
                    toggleRepeatMode()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("字幕预览") {
                    withAnimation {
                        appState.showSubtitlePanel.toggle()
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
    }

    private func togglePlayback() {
        if appState.playerState.playbackState.isPlaying {
            AudioEngine.shared.pause()
        } else if appState.playerState.playbackState == .paused {
            AudioEngine.shared.resume()
        } else if let track = appState.playlist.currentTrack {
            AudioEngine.shared.loadAndPlay(track.audioFile.url)
        }
    }

    private func previousTrack() {
        guard !appState.playlist.tracks.isEmpty else { return }
        let newIndex: Int
        if appState.playlist.currentIndex > 0 {
            newIndex = appState.playlist.currentIndex - 1
        } else if appState.playlist.repeatMode == .all {
            newIndex = appState.playlist.tracks.count - 1
        } else {
            return
        }
        appState.playlist.selectTrack(at: newIndex)
        if let track = appState.playlist.currentTrack {
            AudioEngine.shared.loadAndPlay(track.audioFile.url)
        }
    }

    private func nextTrack() {
        guard !appState.playlist.tracks.isEmpty else { return }
        let newIndex: Int
        if appState.playlist.currentIndex < appState.playlist.tracks.count - 1 {
            newIndex = appState.playlist.currentIndex + 1
        } else if appState.playlist.repeatMode == .all {
            newIndex = 0
        } else {
            return
        }
        appState.playlist.selectTrack(at: newIndex)
        if let track = appState.playlist.currentTrack {
            AudioEngine.shared.loadAndPlay(track.audioFile.url)
        }
    }

    private func toggleRepeatMode() {
        switch appState.playlist.repeatMode {
        case .none:
            appState.playlist.repeatMode = .all
        case .all:
            appState.playlist.repeatMode = .one
        case .one:
            appState.playlist.repeatMode = .none
        }
    }

    private func seekBackward() {
        let currentTime = appState.playbackProgress.currentTime
        let newTime = max(0, currentTime - 5)
        AudioEngine.shared.seek(to: newTime)
    }

    private func seekForward() {
        let currentTime = appState.playbackProgress.currentTime
        let duration = appState.playbackProgress.totalDuration
        let newTime = min(duration, currentTime + 5)
        AudioEngine.shared.seek(to: newTime)
    }

    // MARK: - Folder Operations
    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "选择包含音频文件的文件夹"

        if panel.runModal() == .OK {
            appState.scanAndAddFolders(panel.urls)
        }
    }

    private func openFolderFromHistory(_ item: FolderHistoryItem) {
        guard appState.folderHistoryManager.itemExists(at: item.url) else {
            // 文件夹不存在，从历史中移除
            appState.folderHistoryManager.remove(item)
            return
        }

        // scanAndAddFolder 会自动更新历史
        appState.scanAndAddFolder(item.url)
    }
}

// MARK: - Playback Progress
class PlaybackProgress: ObservableObject {
    @Published var currentTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return currentTime / totalDuration
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var playerState = PlayerState()
    @Published var showSubtitlePanel: Bool = false
    var playlist: Playlist = Playlist()
    var subtitleManager = SubtitleManager()
    var subtitlePreviewManager = SubtitlePreviewManager()
    var playbackProgress = PlaybackProgress()
    var folderHistoryManager = FolderHistoryManager()

    private let fileScanner = FileScanner()

    init() {
        // 初始化音频引擎
        AudioEngine.shared.delegate = self

        // 将 playlist 的变化传播到 AppState
        playlist.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        // 将 subtitleManager 的变化传播到 AppState
        subtitleManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        // 将 subtitlePreviewManager 的变化传播到 AppState
        subtitlePreviewManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        // 注意：不传播 playerState 和 playbackProgress 的高频更新
        // 需要这些更新的视图应直接观察 playerState

        // 监听 playlist 变化自动预加载字幕
        playlist.$tracks.sink { [weak self] tracks in
            self?.subtitlePreviewManager.preloadSubtitles(for: tracks)
        }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Folder Scanning
    func scanAndAddFolder(_ url: URL) {
        // 记录到历史
        folderHistoryManager.add(url)

        fileScanner.scanDirectory(url) { [weak self] tracks in
            DispatchQueue.main.async {
                self?.playlist.addTracks(tracks)
            }
        }
    }

    func scanAndAddFolders(_ urls: [URL]) {
        for url in urls {
            scanAndAddFolder(url)
        }
    }

    // MARK: - Play from Subtitle
    func playFromSubtitle(_ item: SubtitlePreviewItem) {
        // 1. 切换到对应 track
        playlist.selectTrack(at: item.trackIndex)

        // 2. 加载并播放
        if let track = playlist.currentTrack {
            AudioEngine.shared.loadAndPlay(track.audioFile.url)

            // 3. 跳转到字幕时间点
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                AudioEngine.shared.seek(to: item.cue.startTime)
            }
        }
    }
}

// MARK: - Audio Engine Delegate
extension AppState: AudioEngineDelegate {
    func audioEngine(_ engine: AudioEngine, didChangeState state: PlaybackState) {
        DispatchQueue.main.async {
            self.playerState.playbackState = state

            // 播放停止时清除字幕
            if state == .stopped {
                self.subtitleManager.reset()
                self.playerState.currentSubtitle = nil
            }

            // 开始播放时加载字幕并重置进度
            if state == .playing, let track = self.playlist.currentTrack {
                self.playbackProgress.currentTime = 0
                self.playerState.currentTime = 0

                if let subtitleURL = track.audioFile.subtitleURL {
                    self.subtitleManager.load(from: subtitleURL)
                } else {
                    self.subtitleManager.reset()
                }
            }

            // 播放完成时自动播放下一曲
            if state == .finished {
                self.playNextTrack()
            }
        }
    }

    private func playNextTrack() {
        guard !self.playlist.tracks.isEmpty else { return }

        // 单曲循环：重新播放当前曲目
        if self.playlist.repeatMode == .one {
            if let track = self.playlist.currentTrack {
                AudioEngine.shared.loadAndPlay(track.audioFile.url)
            }
            return
        }

        let nextIndex = self.playlist.currentIndex + 1

        if nextIndex < self.playlist.tracks.count {
            self.playlist.currentIndex = nextIndex
            if let track = self.playlist.currentTrack {
                AudioEngine.shared.loadAndPlay(track.audioFile.url)
            }
        } else if self.playlist.repeatMode == .all {
            // 列表循环：回到第一首
            self.playlist.currentIndex = 0
            if let track = self.playlist.currentTrack {
                AudioEngine.shared.loadAndPlay(track.audioFile.url)
            }
        }
        // repeatMode == .none: 播放结束，不继续
    }

    func audioEngine(_ engine: AudioEngine, didUpdateProgress progress: TimeInterval, duration: TimeInterval) {
        DispatchQueue.main.async {
            self.playbackProgress.currentTime = progress
            self.playbackProgress.totalDuration = duration
            self.playerState.currentTime = progress
            self.playerState.totalDuration = duration

            // 更新字幕
            guard self.playerState.playbackState == .playing,
                  self.subtitleManager.cues.count > 0 else { return }

            self.subtitleManager.update(for: progress)
            if let cue = self.subtitleManager.currentCue {
                if self.playerState.currentSubtitle != cue.text {
                    self.playerState.currentSubtitle = cue.text
                }
            } else {
                if self.playerState.currentSubtitle != nil {
                    self.playerState.currentSubtitle = nil
                }
            }
        }
    }

    func audioEngine(_ engine: AudioEngine, didEncounterError error: Error) {
        // Error handling - could show alert to user
    }
}
