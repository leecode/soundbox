import SwiftUI
import Combine

@main
struct SoundBoxApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var playerState = PlayerState()
    var playlist: Playlist = Playlist()
    var subtitleManager = SubtitleManager()

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

        // 将 playerState 的变化传播到 AppState
        playerState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Folder Scanning
    func scanAndAddFolder(_ url: URL) {
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
}

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

        let nextIndex = self.playlist.currentIndex + 1

        if nextIndex < self.playlist.tracks.count {
            self.playlist.currentIndex = nextIndex
            if let track = self.playlist.currentTrack {
                AudioEngine.shared.loadAndPlay(track.audioFile.url)
            }
        } else if self.playlist.repeatMode == .all {
            self.playlist.currentIndex = 0
            if let track = self.playlist.currentTrack {
                AudioEngine.shared.loadAndPlay(track.audioFile.url)
            }
        }
    }

    func audioEngine(_ engine: AudioEngine, didUpdateProgress progress: TimeInterval, duration: TimeInterval) {
        DispatchQueue.main.async {
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
