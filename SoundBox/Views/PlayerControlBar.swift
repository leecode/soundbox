import SwiftUI

struct PlayerControlBar: View {
    @EnvironmentObject var appState: AppState
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            // 进度条
            ProgressSlider(
                value: $sliderValue,
                onEditingChanged: { editing in
                    isDraggingSlider = editing
                    if !editing {
                        AudioEngine.shared.seek(to: sliderValue)
                    }
                }
            )
            .onChange(of: appState.playerState.currentTime) { oldValue, newValue in
                if !isDraggingSlider {
                    sliderValue = newValue
                }
            }

            HStack(spacing: 24) {
                // 左侧：当前曲目信息
                currentTrackInfo
                    .frame(width: 200, alignment: .leading)

                Spacer()

                // 中间：播放控制
                playbackControls

                Spacer()

                // 右侧：时间和音量
                timeAndVolume
                    .frame(width: 200, alignment: .trailing)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Current Track Info
    private var currentTrackInfo: some View {
        HStack(spacing: 12) {
            if let track = appState.playlist.currentTrack {
                // 缩略图
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "waveform")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.body)
                        .lineLimit(1)

                    if let artist = track.artist {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Playback Controls
    private var playbackControls: some View {
        HStack(spacing: 20) {
            // 上一曲
            Button(action: previousTrack) {
                Image(systemName: "backward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(appState.playlist.tracks.isEmpty)

            // 播放/暂停
            Button(action: togglePlayback) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 48, height: 48)

                    Image(systemName: appState.playerState.playbackState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .offset(x: appState.playerState.playbackState.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(.plain)
            .disabled(appState.playlist.tracks.isEmpty)

            // 下一曲
            Button(action: nextTrack) {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(appState.playlist.tracks.isEmpty)
        }
    }

    // MARK: - Time and Volume
    private var timeAndVolume: some View {
        HStack(spacing: 16) {
            // 时间显示
            Text("\(formatTime(appState.playerState.currentTime)) / \(formatTime(appState.playerState.totalDuration))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 100, alignment: .center)

            // 音量
            HStack(spacing: 8) {
                Image(systemName: volumeIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Slider(value: $appState.playerState.volume, in: 0...1)
                    .frame(width: 80)
                    .onChange(of: appState.playerState.volume) { oldValue, newValue in
                        AudioEngine.shared.setVolume(Float(newValue))
                    }
            }
        }
    }

    private var volumeIcon: String {
        let volume = appState.playerState.volume
        if volume == 0 { return "speaker.slash.fill" }
        if volume < 0.33 { return "speaker.wave.1.fill" }
        if volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func togglePlayback() {
        if appState.playerState.playbackState.isPlaying {
            AudioEngine.shared.pause()
        } else if appState.playerState.playbackState == .paused {
            // 暂停状态：继续播放
            AudioEngine.shared.resume()
        } else {
            // 停止状态：从头播放
            if let track = appState.playlist.currentTrack {
                AudioEngine.shared.loadAndPlay(track.audioFile.url)
            }
        }
    }

    private func previousTrack() {
        guard !appState.playlist.tracks.isEmpty else { return }

        let tracksCount = appState.playlist.tracks.count
        let newIndex: Int

        if appState.playlist.currentIndex > 0 {
            newIndex = appState.playlist.currentIndex - 1
        } else if appState.playlist.repeatMode == .all {
            newIndex = tracksCount - 1
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

        let tracksCount = appState.playlist.tracks.count
        let newIndex: Int

        if appState.playlist.currentIndex < tracksCount - 1 {
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
}

// MARK: - Progress Slider
struct ProgressSlider: View {
    @Binding var value: Double
    let onEditingChanged: (Bool) -> Void

    @EnvironmentObject var appState: AppState
    @State private var isDragging = false

    private var range: ClosedRange<Double> {
        0...max(appState.playerState.totalDuration, 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景轨道
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 4)

                // 已播放进度
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)), height: 4)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        onEditingChanged(true)
                        let ratio = Double(gesture.location.x / geometry.size.width)
                        let newValue = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
                        value = max(range.lowerBound, min(range.upperBound, newValue))
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 12)
    }
}
