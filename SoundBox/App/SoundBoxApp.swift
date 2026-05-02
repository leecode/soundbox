import SwiftUI
import Combine
import MediaPlayer

private enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct SoundBoxApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var updateManager = UpdateManager()
    @StateObject private var floatingPanelManager = FloatingPanelManager()
    @AppStorage("app_theme") private var appThemeRawValue: String = AppTheme.system.rawValue

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(updateManager)
                .environmentObject(floatingPanelManager)
                .preferredColorScheme(selectedTheme.colorScheme)
                .frame(minWidth: 900, minHeight: 680)
                .onAppear {
                    floatingPanelManager.configure(appState: appState)
                }
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

                Divider()

                Button(updateManager.isChecking ? "正在检查..." : "检查更新...") {
                    Task {
                        await updateManager.checkForUpdates(force: true)
                    }
                }
                .disabled(updateManager.isChecking)

                Toggle("自动检查更新", isOn: $updateManager.autoCheckUpdates)
            }

            // 播放控制菜单
            CommandMenu("播放") {
                Button("播放/暂停") {
                    appState.togglePlayback()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("上一曲") {
                    appState.goToPreviousTrack()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Button("下一曲") {
                    appState.goToNextTrack()
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

                Button("设置循环起点 A") {
                    appState.setABRepeatStart()
                }
                .disabled(appState.playlist.currentTrack == nil)

                Button("设置循环终点 B") {
                    appState.setABRepeatEnd()
                }
                .disabled(appState.playlist.currentTrack == nil)

                Button("循环当前字幕") {
                    appState.loopCurrentSubtitle()
                }
                .disabled(appState.playlist.currentTrack == nil || appState.subtitleManager.cues.isEmpty)

                if appState.abRepeatRange != nil || appState.pendingABRepeatStart != nil {
                    Button("取消 A-B 循环") {
                        appState.clearABRepeat()
                    }
                }

                Divider()

                Menu("播放速度") {
                    ForEach(AppState.playbackSpeedOptions, id: \.self) { speed in
                        Button(speedLabel(speed)) {
                            appState.setPlaybackSpeed(speed)
                        }
                    }
                }

                Menu("睡眠定时器") {
                    ForEach(AppState.sleepTimerDurations, id: \.self) { minutes in
                        Button("\(minutes) 分钟") {
                            appState.startSleepTimer(minutes: minutes)
                        }
                    }

                    if appState.sleepTimerState.remaining != nil {
                        Divider()

                        Button("取消定时器") {
                            appState.cancelSleepTimer()
                        }
                    }
                }

                Divider()

                Button("字幕预览") {
                    withAnimation {
                        appState.showSubtitlePanel.toggle()
                    }
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("添加书签") {
                    appState.showBookmarkOverlay = true
                }
                .keyboardShortcut("b", modifiers: .command)
            }

            CommandMenu("显示") {
                Picker("主题", selection: $appThemeRawValue) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme.rawValue)
                    }
                }

                Divider()

                Button(floatingPanelManager.isEnabled ? "关闭浮动字幕" : "浮动字幕") {
                    floatingPanelManager.toggle()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
    }

    private func speedLabel(_ speed: Float) -> String {
        String(format: speed.truncatingRemainder(dividingBy: 1) == 0 ? "%.0fx" : "%.2fx", speed)
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
        appState.seekTo(newTime)
    }

    private func seekForward() {
        let currentTime = appState.playbackProgress.currentTime
        let duration = appState.playbackProgress.totalDuration
        let newTime = min(duration, currentTime + 5)
        appState.seekTo(newTime)
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

final class SleepTimerState: ObservableObject {
    @Published var remaining: TimeInterval?
}

// MARK: - App State
class AppState: ObservableObject {
    static let playbackSpeedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    static let sleepTimerDurations = [5, 10, 15, 30, 45, 60, 90, 120]

    @Published var playerState = PlayerState()
    @Published var showSubtitlePanel: Bool = false
    @Published var showBookmarkOverlay: Bool = false
    @Published var errorMessage: String?
    @Published var scriptContent: String?
    @Published var abRepeatRange: ABRepeatRange?
    @Published var pendingABRepeatStart: TimeInterval?
    var playlist: Playlist = Playlist()
    var subtitleManager = SubtitleManager()
    var subtitlePreviewManager = SubtitlePreviewManager()
    var playbackProgress = PlaybackProgress()
    var folderHistoryManager = FolderHistoryManager()
    var playbackPositionManager = PlaybackPositionManager()
    var bookmarkManager = BookmarkManager()
    var sleepTimerState = SleepTimerState()
    private var lastPositionSaveTime: TimeInterval = 0
    private var sleepTimer: Timer?
    private var fadeTimer: Timer?
    private var savedVolumeBeforeFade: Float = 1.0
    private var isSleepFading = false
    private var lastABRepeatSeekTime: TimeInterval = 0

    private let fileScanner = FileScanner()

    // MARK: - Media Key Support
    private var commandCenter: MPRemoteCommandCenter?

    private func setupMediaKeys() {
        let commandCenter = MPRemoteCommandCenter.shared()
        self.commandCenter = commandCenter

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            DispatchQueue.main.async {
                self.togglePlayback()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            DispatchQueue.main.async {
                if self.playerState.playbackState.isPlaying {
                    AudioEngine.shared.pause()
                }
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            DispatchQueue.main.async {
                self.goToNextTrack()
            }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            DispatchQueue.main.async {
                self.goToPreviousTrack()
            }
            return .success
        }
    }

    // MARK: - Unified Playback Controls

    func togglePlayback() {
        if playerState.playbackState.isPlaying {
            AudioEngine.shared.pause()
        } else if playerState.playbackState == .paused {
            AudioEngine.shared.resume()
        } else if let track = playlist.currentTrack {
            restorePlaybackSpeedForCurrentTrack()
            AudioEngine.shared.loadAndPlay(track.audioFile.url)
        }
    }

    func playTrack(at index: Int) {
        guard playlist.tracks.indices.contains(index) else { return }
        cancelSleepFade(restoreVolume: true)
        clearABRepeat()
        playlist.selectTrack(at: index)
        restorePlaybackSpeedForCurrentTrack()
        if let track = playlist.currentTrack {
            AudioEngine.shared.loadAndPlay(track.audioFile.url)
        }
    }

    func goToNextTrack() {
        guard !playlist.tracks.isEmpty else { return }
        cancelSleepFade(restoreVolume: true)
        let newIndex: Int
        if playlist.currentIndex < playlist.tracks.count - 1 {
            newIndex = playlist.currentIndex + 1
        } else if playlist.repeatMode == .all {
            newIndex = 0
        } else {
            return
        }
        clearABRepeat()
        playlist.selectTrack(at: newIndex)
        restorePlaybackSpeedForCurrentTrack()
        if let track = playlist.currentTrack {
            AudioEngine.shared.loadAndPlay(track.audioFile.url)
        }
    }

    func goToPreviousTrack() {
        guard !playlist.tracks.isEmpty else { return }
        cancelSleepFade(restoreVolume: true)
        let newIndex: Int
        if playlist.currentIndex > 0 {
            newIndex = playlist.currentIndex - 1
        } else if playlist.repeatMode == .all {
            newIndex = playlist.tracks.count - 1
        } else {
            return
        }
        clearABRepeat()
        playlist.selectTrack(at: newIndex)
        restorePlaybackSpeedForCurrentTrack()
        if let track = playlist.currentTrack {
            AudioEngine.shared.loadAndPlay(track.audioFile.url)
        }
    }

    func seekTo(_ time: TimeInterval) {
        cancelSleepFade(restoreVolume: true)
        AudioEngine.shared.seek(to: time)
    }

    func setPlaybackSpeed(_ speed: Float) {
        let clampedSpeed = min(max(speed, 0.5), 2.0)
        playerState.playbackRate = clampedSpeed
        AudioEngine.shared.setRate(clampedSpeed)

        if let track = playlist.currentTrack {
            UserDefaults.standard.set(clampedSpeed, forKey: playbackSpeedKey(for: track.audioFile.url))
        }
    }

    func cyclePlaybackSpeed() {
        let current = playerState.playbackRate
        let options = Self.playbackSpeedOptions
        let nextIndex = options.firstIndex(where: { $0 > current + 0.01 }) ?? 0
        setPlaybackSpeed(options[nextIndex])
    }

    func setABRepeatStart(at time: TimeInterval? = nil) {
        guard playlist.currentTrack != nil else { return }
        let startTime = clampedPlaybackTime(time ?? playbackProgress.currentTime)
        pendingABRepeatStart = startTime

        if let currentRange = abRepeatRange,
           currentRange.endTime - startTime >= minimumABRepeatDuration {
            abRepeatRange = ABRepeatRange(startTime: startTime, endTime: currentRange.endTime, source: .manual)
            pendingABRepeatStart = nil
        }
    }

    func setABRepeatEnd(at time: TimeInterval? = nil) {
        guard playlist.currentTrack != nil else { return }
        let endTime = clampedPlaybackTime(time ?? playbackProgress.currentTime)
        let startTime = pendingABRepeatStart ?? abRepeatRange?.startTime ?? playbackProgress.currentTime

        guard endTime - startTime >= minimumABRepeatDuration else {
            errorMessage = "循环终点需要晚于起点"
            return
        }

        abRepeatRange = ABRepeatRange(startTime: startTime, endTime: endTime, source: .manual)
        pendingABRepeatStart = nil
    }

    func loopCurrentSubtitle() {
        guard playlist.currentTrack != nil else { return }

        if !subtitleManager.cues.isEmpty {
            subtitleManager.update(for: playbackProgress.currentTime)
        }

        guard let cue = subtitleManager.currentCue,
              cue.endTime - cue.startTime >= minimumABRepeatDuration else {
            errorMessage = "当前没有可循环的字幕"
            return
        }

        abRepeatRange = ABRepeatRange(startTime: cue.startTime, endTime: cue.endTime, source: .subtitle)
        pendingABRepeatStart = nil
    }

    func clearABRepeat() {
        abRepeatRange = nil
        pendingABRepeatStart = nil
    }

    func startSleepTimer(minutes: Int) {
        startSleepTimer(duration: TimeInterval(minutes * 60))
    }

    func startSleepTimer(duration: TimeInterval) {
        sleepTimer?.invalidate()
        cancelSleepFade(restoreVolume: true)
        sleepTimerState.remaining = duration
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self, let remaining = self.sleepTimerState.remaining else {
                timer.invalidate()
                return
            }

            let nextRemaining = max(remaining - 1, 0)
            self.sleepTimerState.remaining = nextRemaining

            if nextRemaining <= 3, nextRemaining > 0, !self.isSleepFading {
                self.startSmoothFade(duration: nextRemaining)
            }

            if nextRemaining <= 0 {
                self.cancelSleepTimer(restoreVolume: false)
                AudioEngine.shared.pause()
                AudioEngine.shared.setVolume(self.playerState.volume)
            }
        }
    }

    func cancelSleepTimer(restoreVolume: Bool = true) {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerState.remaining = nil
        cancelSleepFade(restoreVolume: restoreVolume)
    }

    init() {
        // 初始化音频引擎
        AudioEngine.shared.delegate = self

        // 初始化媒体键
        setupMediaKeys()

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

        // 将 bookmarkManager 的变化传播到 AppState
        bookmarkManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        // 注意：不传播 playerState 和 playbackProgress 的高频更新
        // 需要这些更新的视图应直接观察 playerState

        // 监听 playlist 变化自动预加载字幕
        playlist.$tracks.sink { [weak self] tracks in
            self?.subtitlePreviewManager.preloadSubtitles(for: tracks)
            self?.prunePlaybackSpeedDefaults(for: tracks)
        }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
    private let minimumABRepeatDuration: TimeInterval = 0.25

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [:]
        if let track = playlist.currentTrack {
            info[MPMediaItemPropertyTitle] = track.title
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info.isEmpty ? nil : info
    }

    private func playbackSpeedKey(for url: URL) -> String {
        "playbackSpeed_\(url.absoluteString)"
    }

    private func restorePlaybackSpeedForCurrentTrack() {
        guard let track = playlist.currentTrack else {
            setPlaybackSpeed(1.0)
            return
        }

        let savedSpeed = UserDefaults.standard.object(forKey: playbackSpeedKey(for: track.audioFile.url)) as? NSNumber
        setPlaybackSpeed(savedSpeed?.floatValue ?? 1.0)
    }

    private func prunePlaybackSpeedDefaults(for tracks: [Track]) {
        let defaults = UserDefaults.standard
        let validKeys = Set(tracks.map { playbackSpeedKey(for: $0.audioFile.url) })
        let speedKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("playbackSpeed_") }
        let extraKeys = speedKeys.filter { !validKeys.contains($0) }

        for key in extraKeys.prefix(max(speedKeys.count - 100, 0)) {
            defaults.removeObject(forKey: key)
        }
    }

    private func clampedPlaybackTime(_ time: TimeInterval) -> TimeInterval {
        let duration = max(playbackProgress.totalDuration, playerState.totalDuration)
        guard duration > 0 else { return max(time, 0) }
        return min(max(time, 0), duration)
    }

    private func handleABRepeatIfNeeded(progress: TimeInterval) -> Bool {
        guard playerState.playbackState == .playing,
              let range = abRepeatRange,
              range.duration >= minimumABRepeatDuration,
              progress >= range.endTime else {
            return false
        }

        let now = Date().timeIntervalSince1970
        guard now - lastABRepeatSeekTime >= 0.2 else {
            return true
        }

        lastABRepeatSeekTime = now
        AudioEngine.shared.seek(to: range.startTime)
        playbackProgress.currentTime = range.startTime
        playerState.currentTime = range.startTime
        subtitlePreviewManager.updateActiveItem(for: range.startTime, currentTrackIndex: playlist.currentIndex)

        if !subtitleManager.cues.isEmpty {
            subtitleManager.update(for: range.startTime)
            playerState.currentSubtitle = subtitleManager.currentCue?.text
        }

        return true
    }

    private func startSmoothFade(duration: TimeInterval) {
        cancelSleepFade(restoreVolume: false)
        isSleepFading = true
        savedVolumeBeforeFade = playerState.volume

        let totalSteps = 60
        let stepInterval = max(duration / Double(totalSteps), 0.02)
        var step = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            step += 1
            let progress = min(Float(step) / Float(totalSteps), 1.0)
            AudioEngine.shared.setVolume(self.savedVolumeBeforeFade * (1.0 - progress))

            if step >= totalSteps {
                timer.invalidate()
            }
        }
    }

    private func cancelSleepFade(restoreVolume: Bool) {
        fadeTimer?.invalidate()
        fadeTimer = nil

        if isSleepFading && restoreVolume {
            AudioEngine.shared.setVolume(playerState.volume)
        }

        isSleepFading = false
    }

    // MARK: - Folder Scanning
    func scanAndAddFolder(_ url: URL) {
        // 记录到历史
        folderHistoryManager.add(url)

        fileScanner.scanDirectory(url) { [weak self] tracks in
            DispatchQueue.main.async {
                self?.playlist.addTracks(tracks)
                self?.updateNowPlayingInfo()
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
        clearABRepeat()
        playlist.selectTrack(at: item.trackIndex)
        restorePlaybackSpeedForCurrentTrack()

        // 2. 加载并播放
        if let track = playlist.currentTrack {
            AudioEngine.shared.loadAndPlay(track.audioFile.url)

            // 3. 跳转到字幕时间点
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.seekTo(item.cue.startTime)
            }
        }
    }

    // MARK: - Bookmarks
    func addBookmarkAtCurrentPosition(label: String = "") {
        guard let track = playlist.currentTrack else { return }
        let timestamp = playbackProgress.currentTime
        bookmarkManager.addBookmark(audioFileURL: track.audioFile.url, timestamp: timestamp, label: label)
    }

    func currentFileBookmarks() -> [Bookmark] {
        guard let track = playlist.currentTrack else { return [] }
        return bookmarkManager.bookmarks(for: track.audioFile.url)
    }

    // MARK: - Script Loading
    func loadScript(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var usedEncoding: UInt = 0
            var content: String?

            // Try automatic detection first
            if let str = try? NSString(contentsOf: url, usedEncoding: &usedEncoding) as String {
                content = str
            } else {
                // Fallback chain: UTF-8 → Shift-JIS → ASCII
                let encodings: [String.Encoding] = [.utf8, .init(rawValue: UInt(CFStringEncodings.shiftJIS.rawValue)), .ascii]
                for encoding in encodings {
                    if let str = try? String(contentsOf: url, encoding: encoding) {
                        content = str
                        break
                    }
                }
            }

            DispatchQueue.main.async {
                self?.scriptContent = content
            }
        }
    }
}

// MARK: - Audio Engine Delegate
extension AppState: AudioEngineDelegate {
    func audioEngine(_ engine: AudioEngine, didChangeState state: PlaybackState) {
        DispatchQueue.main.async {
            self.playerState.playbackState = state
            self.updateNowPlayingInfo()

            // 播放停止时清除字幕
            if state == .stopped {
                self.subtitleManager.reset()
                self.playerState.currentSubtitle = nil
            }

            // 暂停/停止时保存进度
            if (state == .paused || state == .stopped),
               let track = self.playlist.currentTrack {
                self.playbackPositionManager.savePosition(
                    for: track.audioFile.url,
                    position: self.playbackProgress.currentTime,
                    duration: self.playbackProgress.totalDuration
                )
            }

            // 播放完成时移除保存的进度
            if state == .finished, let track = self.playlist.currentTrack {
                self.playbackPositionManager.removePosition(for: track.audioFile.url)
            }

            // 开始播放时加载字幕并重置进度
            if state == .playing, let track = self.playlist.currentTrack {
                self.playbackProgress.currentTime = 0
                self.playerState.currentTime = 0

                // App 启动后恢复上次的播放位置（仅一次）
                if let savedPosition = self.playbackPositionManager.restorePositionIfNeeded(for: track.audioFile.url) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        self.seekTo(savedPosition)
                    }
                }

                if let subtitleURL = track.audioFile.subtitleURL {
                    self.subtitleManager.load(from: subtitleURL)
                } else {
                    self.subtitleManager.reset()
                }

                // 加载台本
                if let scriptURL = track.audioFile.scriptURL {
                    self.loadScript(from: scriptURL)
                } else {
                    self.scriptContent = nil
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

        // 尝试下一曲
        let wasAtLastTrack = self.playlist.currentIndex >= self.playlist.tracks.count - 1
        goToNextTrack()

        // 如果 goToNextTrack 没有切换（.none 模式，最后一曲），回到 stopped
        if wasAtLastTrack && self.playerState.playbackState == .finished {
            AudioEngine.shared.stop()
        }
    }

    func audioEngine(_ engine: AudioEngine, didUpdateProgress progress: TimeInterval, duration: TimeInterval) {
        DispatchQueue.main.async {
            self.playbackProgress.currentTime = progress
            self.playbackProgress.totalDuration = duration
            self.playerState.currentTime = progress
            self.playerState.totalDuration = duration

            // 节流保存播放进度（每5秒）
            let now = Date().timeIntervalSince1970
            if now - self.lastPositionSaveTime >= 5.0 {
                self.lastPositionSaveTime = now
                if let track = self.playlist.currentTrack {
                    self.playbackPositionManager.savePosition(
                        for: track.audioFile.url,
                        position: progress,
                        duration: duration
                    )
                }
            }

            // 更新字幕列表高亮（始终高亮离当前时间最近的字幕）
            self.subtitlePreviewManager.updateActiveItem(for: progress, currentTrackIndex: self.playlist.currentIndex)

            if self.handleABRepeatIfNeeded(progress: progress) {
                return
            }

            // 更新字幕显示
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
        DispatchQueue.main.async {
            self.errorMessage = error.localizedDescription
        }
    }
}
