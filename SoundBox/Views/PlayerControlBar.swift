import SwiftUI

struct PlayerControlBar: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var playerState: PlayerState
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0

    private var currentBookmarks: [Bookmark] {
        appState.currentFileBookmarks()
    }

    var body: some View {
        VStack(spacing: 0) {
            // 进度条
            ProgressSlider(
                value: $sliderValue,
                totalDuration: playerState.totalDuration,
                bookmarks: currentBookmarks,
                onBookmarkSeek: { time in
                    appState.seekTo(time)
                },
                onEditingChanged: { editing in
                    isDraggingSlider = editing
                    if !editing {
                        AudioEngine.shared.seek(to: sliderValue)
                    }
                }
            )
            .onChange(of: playerState.currentTime) { oldValue, newValue in
                if !isDraggingSlider {
                    sliderValue = newValue
                }
            }

            HStack(alignment: .center, spacing: 24) {
                // 左侧：当前曲目信息
                currentTrackInfo
                    .frame(width: 200, alignment: .leading)

                Spacer()

                // 中间：播放控制
                playbackControls
                    .frame(maxHeight: .infinity)

                Spacer()

                // 右侧：时间和音量
                timeAndVolume
                    .frame(width: 200, alignment: .trailing)
            }
            .frame(maxHeight: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .frame(maxHeight: .infinity)
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
            .frame(width: 44, height: 44)
            .disabled(appState.playlist.tracks.isEmpty)

            // 播放/暂停
            Button(action: togglePlayback) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 48, height: 48)

                    Image(systemName: playerState.playbackState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .offset(x: playerState.playbackState.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(.plain)
            .offset(y: -2)
            .disabled(appState.playlist.tracks.isEmpty)

            // 下一曲
            Button(action: nextTrack) {
                Image(systemName: "forward.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .disabled(appState.playlist.tracks.isEmpty)

            // 循环模式
            Button(action: toggleRepeatMode) {
                Image(systemName: repeatModeIcon)
                    .font(.title3)
                    .foregroundColor(appState.playlist.repeatMode == .none ? .secondary : .accentColor)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .help(repeatModeHelpText)

            // 书签
            Button(action: {
                appState.showBookmarkOverlay = true
            }) {
                Image(systemName: "bookmark")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .help("添加书签 (⌘B)")
            .disabled(appState.playlist.tracks.isEmpty)
        }
    }

    private var repeatModeIcon: String {
        switch appState.playlist.repeatMode {
        case .none: return "repeat"
        case .one: return "repeat.1"
        case .all: return "repeat"
        }
    }

    private var repeatModeHelpText: String {
        switch appState.playlist.repeatMode {
        case .none: return "循环: 关闭"
        case .one: return "循环: 单曲"
        case .all: return "循环: 列表"
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

    // MARK: - Time and Volume
    private var timeAndVolume: some View {
        HStack(spacing: 16) {
            // 时间显示
            Text("\(FormatUtils.formatTime(playerState.currentTime)) / \(FormatUtils.formatTime(playerState.totalDuration))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 100, alignment: .center)

            // 字幕预览按钮
            Button(action: {
                withAnimation {
                    appState.showSubtitlePanel.toggle()
                }
            }) {
                Image(systemName: "text.bubble")
                    .font(.caption)
                    .foregroundStyle(appState.showSubtitlePanel ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("字幕预览 (⌘S)")
            .opacity(appState.subtitlePreviewManager.items.isEmpty ? 0.3 : 1.0)
            .disabled(appState.subtitlePreviewManager.items.isEmpty)

            // 音量
            HStack(spacing: 8) {
                Image(systemName: volumeIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Slider(value: $playerState.volume, in: 0...1)
                    .frame(width: 80)
                    .onChange(of: playerState.volume) { oldValue, newValue in
                        AudioEngine.shared.setVolume(Float(newValue))
                    }
            }
        }
    }

    private var volumeIcon: String {
        let volume = playerState.volume
        if volume == 0 { return "speaker.slash.fill" }
        if volume < 0.33 { return "speaker.wave.1.fill" }
        if volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func togglePlayback() {
        appState.togglePlayback()
    }

    private func previousTrack() {
        appState.goToPreviousTrack()
    }

    private func nextTrack() {
        appState.goToNextTrack()
    }
}

// MARK: - Progress Slider
struct ProgressSlider: View {
    @Binding var value: Double
    let totalDuration: Double
    let bookmarks: [Bookmark]
    let onBookmarkSeek: ((TimeInterval) -> Void)?
    let onEditingChanged: (Bool) -> Void

    @State private var isDragging = false
    @State private var isHovering = false
    @State private var hoverLocation: CGFloat = 0

    private var range: ClosedRange<Double> {
        0...max(totalDuration, 1)
    }

    private var progress: CGFloat {
        CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    private var hoverTime: Double {
        let ratio = Double(hoverLocation)
        return range.lowerBound + ratio * (range.upperBound - range.lowerBound)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 扩大点击区域
                Color.clear
                    .frame(height: 24)
                    .contentShape(Rectangle())

                // 背景轨道
                RoundedRectangle(cornerRadius: isHovering || isDragging ? 3 : 2)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: isHovering || isDragging ? 6 : 4)

                // 已播放进度
                RoundedRectangle(cornerRadius: isHovering || isDragging ? 3 : 2)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: isHovering || isDragging ? 6 : 4)

                // 书签标记
                ForEach(bookmarks) { bookmark in
                    let ratio = CGFloat((bookmark.timestamp - range.lowerBound) / (range.upperBound - range.lowerBound))
                    if ratio > 0 && ratio < 1 {
                        Rectangle()
                            .fill(Color.orange.opacity(0.8))
                            .frame(width: 2, height: isHovering || isDragging ? 10 : 6)
                            .offset(x: geometry.size.width * ratio - 1)
                            .contentShape(Rectangle().size(width: 10, height: 14))
                            .onTapGesture {
                                onBookmarkSeek?(bookmark.timestamp)
                            }
                            .help(bookmark.label.isEmpty ? FormatUtils.formatTime(bookmark.timestamp) : "\(bookmark.label) (\(FormatUtils.formatTime(bookmark.timestamp)))")
                    }
                }

                // 悬停时显示预览线
                if isHovering && !isDragging {
                    Rectangle()
                        .fill(Color.primary.opacity(0.3))
                        .frame(width: 1, height: 10)
                        .offset(x: geometry.size.width * hoverLocation - 0.5)

                    // 时间预览气泡
                    Text(FormatUtils.formatTime(hoverTime))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(4)
                        .offset(
                            x: min(max(geometry.size.width * hoverLocation - 20, 0), geometry.size.width - 40),
                            y: -20
                        )
                }

                // 拖拽手柄
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging ? 14 : (isHovering ? 12 : 0), height: isDragging ? 14 : (isHovering ? 12 : 0))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: geometry.size.width * progress - (isDragging ? 7 : (isHovering ? 6 : 0)))
                    .opacity(isHovering || isDragging ? 1 : 0)
            }
            .frame(maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged(true)
                        }
                        let ratio = Double(gesture.location.x / geometry.size.width)
                        let newValue = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
                        value = max(range.lowerBound, min(range.upperBound, newValue))
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged(false)
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    isHovering = true
                    hoverLocation = location.x / geometry.size.width
                case .ended:
                    isHovering = false
                }
            }
        }
        .frame(height: 24)
    }
}
