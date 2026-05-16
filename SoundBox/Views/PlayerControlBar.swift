import SwiftUI

struct PlayerControlBar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sleepTimerState: SleepTimerState
    @ObservedObject var playerState: PlayerState
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0
    @State private var showCompanionPopover = false

    private var currentBookmarks: [Bookmark] {
        appState.currentFileBookmarks()
    }

    private var hasTrack: Bool {
        !appState.playlist.tracks.isEmpty
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 980

            HStack(spacing: compact ? 12 : 20) {
                currentTrackInfo
                    .frame(width: compact ? 170 : 220, alignment: .leading)

                timelineSection(compact: compact)
                    .layoutPriority(1)

                rightControls(compact: compact)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, compact ? 12 : 20)
            .padding(.vertical, 14)
        }
        .onAppear {
            sliderValue = playerState.currentTime
        }
    }

    private var currentTrackInfo: some View {
        HStack(spacing: 10) {
            if let track = appState.playlist.currentTrack {
                AsyncArtworkView(
                    embeddedData: track.audioFile.embeddedArtworkData,
                    artworkURL: track.audioFile.artworkURL,
                    cornerRadius: DesignTokens.Radius.small
                )
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.subheadline)
                        .lineLimit(1)

                    Text(track.artist ?? "未知艺术家")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Image(systemName: "music.note")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small))

                VStack(alignment: .leading, spacing: 1) {
                    Text("未选择音频")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("请先导入文件夹")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func timelineSection(compact: Bool) -> some View {
        HStack(spacing: compact ? 8 : 12) {
            Text(FormatUtils.formatTime(playerState.currentTime))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .frame(width: compact ? 40 : 46, alignment: .trailing)

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
                        appState.seekTo(sliderValue)
                    }
                }
            )
            .onChange(of: playerState.currentTime) { _, newValue in
                if !isDraggingSlider {
                    sliderValue = newValue
                }
            }
            .disabled(!hasTrack)

            Text(FormatUtils.formatTime(playerState.totalDuration))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .frame(width: compact ? 40 : 46, alignment: .leading)
        }
    }

    private func rightControls(compact: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            if !compact {
                controlsRow(showRepeat: true, showBookmark: true, showSpeed: true, volumeWidth: 62)
            }
            controlsRow(showRepeat: true, showBookmark: true, showSpeed: false, volumeWidth: compact ? 42 : 46)
            controlsRow(showRepeat: false, showBookmark: false, showSpeed: false, volumeWidth: 36)
        }
    }

    private func controlsRow(showRepeat: Bool, showBookmark: Bool, showSpeed: Bool, volumeWidth: CGFloat) -> some View {
        HStack(spacing: 8) {
            Button(action: previousTrack) {
                Image(systemName: "backward.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .disabled(!hasTrack)

            Button(action: togglePlayback) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 34, height: 34)

                    Image(systemName: playerState.playbackState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .offset(x: playerState.playbackState.isPlaying ? 0 : 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(!hasTrack)

            Button(action: nextTrack) {
                Image(systemName: "forward.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .disabled(!hasTrack)

            if showRepeat {
                Button(action: toggleRepeatMode) {
                    Image(systemName: repeatModeIcon)
                        .font(.caption)
                        .foregroundStyle(appState.playlist.repeatMode == .none ? .secondary : Color.accentColor)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .help(repeatModeHelpText)
            }

            if showBookmark {
                Button(action: {
                    appState.showBookmarkOverlay = true
                }) {
                    Image(systemName: "bookmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .help("添加书签 (⌘B)")
                .disabled(!hasTrack)
            }

            Button(action: {
                appState.toggleSidePanel(.subtitles)
            }) {
                Image(systemName: "text.bubble")
                    .font(.caption)
                    .foregroundStyle(appState.isSidePanelShowing(.subtitles) ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .help("字幕预览 (⌘S)")
            .opacity(appState.subtitlePreviewManager.items.isEmpty ? 0.35 : 1.0)
            .disabled(appState.subtitlePreviewManager.items.isEmpty)

            Button(action: {
                showCompanionPopover.toggle()
            }) {
                Image(systemName: "iphone")
                    .font(.caption)
                    .foregroundStyle(appState.companionServer.isRunning ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .help("手机伴侣")
            .popover(isPresented: $showCompanionPopover, arrowEdge: .top) {
                CompanionControlView(server: appState.companionServer)
                    .environmentObject(appState)
            }

            if let abRepeatRange = appState.abRepeatRange {
                Button(action: appState.clearABRepeat) {
                    HStack(spacing: 4) {
                        Image(systemName: abRepeatRange.source == .subtitle ? "text.bubble.fill" : "repeat")
                            .font(.caption2)
                        Text(formatABRepeatRange(abRepeatRange))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("取消 A-B 循环")
            } else if let pendingStart = appState.pendingABRepeatStart {
                Button(action: appState.clearABRepeat) {
                    HStack(spacing: 4) {
                        Image(systemName: "a.circle")
                            .font(.caption2)
                        Text(FormatUtils.formatTime(pendingStart))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("已设置循环起点，点击取消")
            }

            if let remaining = sleepTimerState.remaining {
                Button(action: {
                    appState.cancelSleepTimer()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                            .font(.caption2)
                        Text(formatTimer(remaining))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("取消睡眠定时器")
            }

            Image(systemName: volumeIcon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Slider(value: $playerState.volume, in: 0...1)
                .frame(width: volumeWidth)
                .onChange(of: playerState.volume) { _, newValue in
                    AudioEngine.shared.setVolume(Float(newValue))
                }

            if showSpeed {
                Button(action: appState.cyclePlaybackSpeed) {
                    Text(formatSpeed(playerState.playbackRate))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(abs(playerState.playbackRate - 1.0) < 0.01 ? Color.secondary : Color.accentColor)
                        .frame(width: 40)
                }
                .buttonStyle(.plain)
                .help("播放速度")
            }
        }
    }

    private func formatTimer(_ remaining: TimeInterval) -> String {
        let totalSeconds = max(Int(remaining.rounded(.up)), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatSpeed(_ speed: Float) -> String {
        if abs(speed.rounded() - speed) < 0.01 {
            return String(format: "%.0fx", speed)
        }
        return String(format: "%.2fx", speed)
    }

    private func formatABRepeatRange(_ range: ABRepeatRange) -> String {
        let prefix = range.source == .subtitle ? "句" : "A-B"
        return "\(prefix) \(FormatUtils.formatTime(range.startTime))-\(FormatUtils.formatTime(range.endTime))"
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
                Color.clear
                    .frame(height: 24)
                    .contentShape(Rectangle())

                RoundedRectangle(cornerRadius: isHovering || isDragging ? 3 : 2)
                    .fill(Color.secondary.opacity(0.28))
                    .frame(height: isHovering || isDragging ? DesignTokens.Slider.hoverHeight : DesignTokens.Slider.normalHeight)

                RoundedRectangle(cornerRadius: isHovering || isDragging ? 3 : 2)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: isHovering || isDragging ? DesignTokens.Slider.hoverHeight : DesignTokens.Slider.normalHeight)

                ForEach(bookmarks) { bookmark in
                    let ratio = CGFloat((bookmark.timestamp - range.lowerBound) / (range.upperBound - range.lowerBound))
                    if ratio > 0 && ratio < 1 {
                        Rectangle()
                            .fill(DesignTokens.Colors.bookmark)
                            .frame(width: DesignTokens.Slider.bookmarkWidth, height: DesignTokens.Slider.bookmarkHeight)
                            .offset(x: geometry.size.width * ratio - 1)
                            .contentShape(Rectangle().size(width: 10, height: 14))
                            .onTapGesture {
                                onBookmarkSeek?(bookmark.timestamp)
                            }
                            .help(bookmark.label.isEmpty ? FormatUtils.formatTime(bookmark.timestamp) : "\(bookmark.label) (\(FormatUtils.formatTime(bookmark.timestamp)))")
                    }
                }

                if isHovering && !isDragging {
                    Rectangle()
                        .fill(Color.primary.opacity(0.28))
                        .frame(width: 1, height: 10)
                        .offset(x: geometry.size.width * hoverLocation - 0.5)

                    Text(FormatUtils.formatTime(hoverTime))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
                        .offset(
                            x: min(max(geometry.size.width * hoverLocation - 20, 0), geometry.size.width - 40),
                            y: -20
                        )
                }

                Circle()
                    .fill(Color.white)
                    .frame(
                        width: isDragging ? DesignTokens.Slider.draggingHandleSize : (isHovering ? DesignTokens.Slider.handleSize : 0),
                        height: isDragging ? DesignTokens.Slider.draggingHandleSize : (isHovering ? DesignTokens.Slider.handleSize : 0)
                    )
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
                    let normalized = location.x / max(geometry.size.width, 1)
                    hoverLocation = min(max(normalized, 0), 1)
                case .ended:
                    isHovering = false
                }
            }
        }
        .frame(height: 24)
    }
}
