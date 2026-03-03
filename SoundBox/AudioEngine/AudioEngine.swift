import Foundation
import AVFAudio

// MARK: - Audio Engine Delegate
protocol AudioEngineDelegate: AnyObject {
    func audioEngine(_ engine: AudioEngine, didChangeState state: PlaybackState)
    func audioEngine(_ engine: AudioEngine, didUpdateProgress progress: TimeInterval, duration: TimeInterval)
    func audioEngine(_ engine: AudioEngine, didEncounterError error: Error)
}

// MARK: - Audio Engine
class AudioEngine {
    static let shared = AudioEngine()

    weak var delegate: AudioEngineDelegate?

    // MARK: - Private Properties
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    private var audioFile: AVAudioFile?
    private var totalDuration: TimeInterval = 0
    private var isPlaying = false
    private var currentURL: URL?

    private var progressTimer: Timer?
    private var playStartTime: TimeInterval = 0  // 记录每次播放的起始时间偏移

    // MARK: - Initialization
    private init() {
        audioEngine.attach(playerNode)
        print("🔊 音频引擎初始化完成")
    }

    // MARK: - Public Methods
    func loadAndPlay(_ url: URL) {
        print("🎵 加载并播放: \(url.lastPathComponent)")

        // 停止当前播放
        stop()

        currentURL = url
        delegate?.audioEngine(self, didChangeState: .loading)

        do {
            // 打开音频文件
            audioFile = try AVAudioFile(forReading: url)

            guard let audioFile = audioFile else {
                delegate?.audioEngine(self, didChangeState: .error("无法打开音频文件"))
                return
            }

            // 获取音频信息
            let format = audioFile.processingFormat
            let frameCount = audioFile.length
            totalDuration = Double(frameCount) / format.sampleRate

            print("📊 音频信息: \(format.sampleRate)Hz, \(format.channelCount)声道, 时长:\(String(format: "%.1f", totalDuration))秒")

            // 使用文件的格式连接到主混合器（让 AVAudioEngine 自动处理格式转换）
            audioEngine.disconnectNodeInput(audioEngine.mainMixerNode, bus: 0)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)

            // 启动音频引擎
            if !audioEngine.isRunning {
                try audioEngine.start()
                print("🔊 音频引擎已启动")
            }

            // 从文件开头开始播放
            audioFile.framePosition = 0
            playStartTime = 0  // 从头开始播放

            // 安排播放整个文件
            playerNode.stop()
            playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                self?.handlePlaybackComplete()
            }

            // 开始播放
            playerNode.play()
            isPlaying = true

            // 启动进度更新定时器
            startProgressTimer()

            delegate?.audioEngine(self, didChangeState: .playing)
            print("▶️ 播放已开始")

        } catch {
            print("❌ 播放失败: \(error)")
            delegate?.audioEngine(self, didEncounterError: error)
            delegate?.audioEngine(self, didChangeState: .error(error.localizedDescription))
        }
    }

    private func handlePlaybackComplete() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isPlaying {
                self.isPlaying = false
                self.stopProgressTimer()
                self.delegate?.audioEngine(self, didChangeState: .finished)
                print("⏹️ 播放完成")
            }
        }
    }

    func pause() {
        guard isPlaying else { return }

        playerNode.pause()
        isPlaying = false
        stopProgressTimer()
        delegate?.audioEngine(self, didChangeState: .paused)
        print("⏸️ 已暂停")
    }

    func resume() {
        guard !isPlaying, audioFile != nil else { return }

        if !audioEngine.isRunning {
            try? audioEngine.start()
        }

        playerNode.play()
        isPlaying = true
        startProgressTimer()
        delegate?.audioEngine(self, didChangeState: .playing)
        print("▶️ 继续播放")
    }

    func stop() {
        playerNode.stop()
        isPlaying = false
        stopProgressTimer()

        if audioEngine.isRunning {
            audioEngine.pause()
        }

        audioFile = nil
        delegate?.audioEngine(self, didChangeState: .stopped)
    }

    func seek(to time: TimeInterval) {
        guard let audioFile = audioFile else { return }

        let framePosition = AVAudioFramePosition(time * audioFile.processingFormat.sampleRate)
        let clampedPosition = max(0, min(framePosition, audioFile.length))

        // 停止当前播放
        playerNode.stop()

        // 设置新位置
        audioFile.framePosition = clampedPosition
        playStartTime = time  // 更新播放起始时间

        // 重新安排从新位置开始的播放
        playerNode.scheduleFile(audioFile, at: nil, completionHandler: { [weak self] in
            self?.handlePlaybackComplete()
        })

        if isPlaying {
            playerNode.play()
        }

        // 立即更新进度
        updateProgress()
    }

    func setVolume(_ volume: Float) {
        playerNode.volume = volume
    }

    // MARK: - Progress Timer
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard isPlaying else { return }

        // 使用 playerNode 的播放时间，而不是 audioFile.framePosition
        // framePosition 只是文件读取指针，不会反映实际播放位置
        let currentTime: TimeInterval

        if let lastRenderTime = playerNode.lastRenderTime,
           let playerTime = playerNode.playerTime(forNodeTime: lastRenderTime) {
            // playerTime 是从每次 scheduleFile 开始计算的，需要加上起始偏移
            currentTime = playStartTime + Double(playerTime.sampleTime) / playerTime.sampleRate
        } else {
            currentTime = playStartTime
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.audioEngine(self, didUpdateProgress: currentTime, duration: self.totalDuration)
        }
    }
}
