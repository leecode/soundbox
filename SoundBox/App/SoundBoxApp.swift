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
    }

    private var cancellables = Set<AnyCancellable>()
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

            // 开始播放时加载字幕
            if state == .playing, let track = self.playlist.currentTrack {
                print("📝 检查字幕: subtitleURL = \(track.audioFile.subtitleURL?.path ?? "nil")")
                if let subtitleURL = track.audioFile.subtitleURL {
                    print("📝 加载字幕: \(subtitleURL.lastPathComponent)")
                    self.subtitleManager.load(from: subtitleURL)
                } else {
                    print("📝 当前曲目没有字幕文件")
                    self.subtitleManager.reset()
                }
            }
        }
    }

    func audioEngine(_ engine: AudioEngine, didUpdateProgress progress: TimeInterval, duration: TimeInterval) {
        DispatchQueue.main.async {
            self.playerState.currentTime = progress
            self.playerState.totalDuration = duration

            // 更新字幕
            let cuesCount = self.subtitleManager.cues.count
            let isPlaying = self.playerState.playbackState == .playing

            // 每秒打印一次调试信息
            if Int(progress) % 5 == 0 && Int(progress * 10) % 10 == 0 {
                print("⏱️ 进度: \(String(format: "%.1f", progress))s, cues: \(cuesCount), isPlaying: \(isPlaying)")
            }

            if isPlaying && cuesCount > 0 {
                self.subtitleManager.update(for: progress)
                if let cue = self.subtitleManager.currentCue {
                    if self.playerState.currentSubtitle != cue.text {
                        self.playerState.currentSubtitle = cue.text
                        print("📝 字幕更新: \(cue.text)")
                    }
                } else {
                    if self.playerState.currentSubtitle != nil {
                        self.playerState.currentSubtitle = nil
                    }
                }
            }
        }
    }

    func audioEngine(_ engine: AudioEngine, didEncounterError error: Error) {
        print("Audio Engine Error: \(error.localizedDescription)")
    }
}
