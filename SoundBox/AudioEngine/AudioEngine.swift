import Foundation
import AVFAudio
import os.log

// MARK: - Audio Engine Delegate
protocol AudioEngineDelegate: AnyObject {
    func audioEngine(_ engine: AudioEngine, didChangeState state: PlaybackState)
    func audioEngine(_ engine: AudioEngine, didUpdateProgress progress: TimeInterval, duration: TimeInterval)
    func audioEngine(_ engine: AudioEngine, didEncounterError error: Error)
}

// MARK: - Audio Engine
class AudioEngine {
    static let shared = AudioEngine()
    private static let logger = Logger(subsystem: "com.soundbox", category: "AudioEngine")

    weak var delegate: AudioEngineDelegate?

    // MARK: - Private Properties
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchNode = AVAudioUnitTimePitch()

    private var audioFile: AVAudioFile?
    private var totalDuration: TimeInterval = 0
    private var isPlaying = false
    private var currentURL: URL?

    private var progressTimer: Timer?
    private var playStartTime: TimeInterval = 0
    private var playbackToken: UInt32 = 0

    // MARK: - Initialization
    private init() {
        audioEngine.attach(playerNode)
        audioEngine.attach(timePitchNode)
    }

    // MARK: - Public Methods
    func loadAndPlay(_ url: URL) {
        stop()

        currentURL = url
        delegate?.audioEngine(self, didChangeState: .loading)

        do {
            audioFile = try AVAudioFile(forReading: url)

            guard let audioFile = audioFile else {
                delegate?.audioEngine(self, didChangeState: .error("无法打开音频文件"))
                return
            }

            let format = audioFile.processingFormat
            let frameCount = audioFile.length
            totalDuration = Double(frameCount) / format.sampleRate

            audioEngine.disconnectNodeOutput(playerNode)
            audioEngine.disconnectNodeOutput(timePitchNode)
            audioEngine.disconnectNodeInput(audioEngine.mainMixerNode, bus: 0)
            audioEngine.connect(playerNode, to: timePitchNode, format: format)
            audioEngine.connect(timePitchNode, to: audioEngine.mainMixerNode, format: format)

            if !audioEngine.isRunning {
                try audioEngine.start()
            }

            audioFile.framePosition = 0
            playStartTime = 0
            playbackToken &+= 1

            playerNode.stop()
            let token = playbackToken
            playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                self?.handlePlaybackComplete(token: token)
            }

            playerNode.play()
            isPlaying = true

            delegate?.audioEngine(self, didUpdateProgress: 0, duration: totalDuration)
            startProgressTimer()
            delegate?.audioEngine(self, didChangeState: .playing)

        } catch {
            delegate?.audioEngine(self, didEncounterError: error)
            delegate?.audioEngine(self, didChangeState: .error(error.localizedDescription))
        }
    }

    private func handlePlaybackComplete(token: UInt32) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // All state checks happen on main thread to avoid data races
            guard self.playbackToken == token else { return }

            if self.isPlaying {
                self.isPlaying = false
                self.stopProgressTimer()
                self.delegate?.audioEngine(self, didChangeState: .finished)
            }
        }
    }

    func pause() {
        guard isPlaying else { return }

        playerNode.pause()
        isPlaying = false
        stopProgressTimer()
        delegate?.audioEngine(self, didChangeState: .paused)
    }

    func resume() {
        guard !isPlaying, audioFile != nil else { return }

        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                Self.logger.error("Failed to start audio engine on resume: \(error.localizedDescription)")
                delegate?.audioEngine(self, didEncounterError: error)
                delegate?.audioEngine(self, didChangeState: .error(error.localizedDescription))
                return
            }
        }

        playerNode.play()
        isPlaying = true
        startProgressTimer()
        delegate?.audioEngine(self, didChangeState: .playing)
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

        let sampleRate = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        let clampedStart = max(0, min(startFrame, audioFile.length))
        let frameCount = AVAudioFrameCount(audioFile.length - clampedStart)

        guard frameCount > 0 else { return }

        playbackToken &+= 1
        let token = playbackToken

        playerNode.stop()
        playStartTime = time

        playerNode.scheduleSegment(audioFile, startingFrame: clampedStart, frameCount: frameCount, at: nil, completionHandler: { [weak self] in
            self?.handlePlaybackComplete(token: token)
        })

        if isPlaying {
            playerNode.play()
        }

        updateProgress()
    }

    func setVolume(_ volume: Float) {
        playerNode.volume = volume
    }

    func setRate(_ rate: Float) {
        timePitchNode.rate = min(max(rate, 0.5), 2.0)
    }

    // MARK: - Progress Timer
    private func startProgressTimer() {
        stopProgressTimer()
        // 降低更新频率到 0.25 秒，减少 CPU 占用
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        let currentTime: TimeInterval

        if isPlaying,
           let lastRenderTime = playerNode.lastRenderTime,
           let playerTime = playerNode.playerTime(forNodeTime: lastRenderTime) {
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
