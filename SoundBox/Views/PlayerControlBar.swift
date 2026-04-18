import SwiftUI

struct PlayerControlBar: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var playerState: PlayerState
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0

    private var currentBookmarks: [Bookmark] {
        appState.currentFileBookmarks()
    }

    private var hasTrack: Bool {
        !appState.playlist.tracks.isEmpty
    }

    var body: some View {
        HStack(spacing: 20) {
            currentTrackInfo
                .frame(width: 220, alignment: .leading)

            timelineSection
                .frame(maxWidth: .infinity)

            rightControls
                .frame(width: 220, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
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

    private var timelineSection: some View {
        HStack(spacing: 12) {
            Text(FormatUtils.formatTime(playerState.currentTime))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .frame(width: 46, alignment: .trailing)

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
                .frame(width: 46, alignment: .leading)
        }
    }

    private var rightControls: some View {
        ViewThatFits(in: .horizontal) {
            controlsRow(showSpeed: true, volumeWidth: 62)
            controlsRow(showSpeed: false, volumeWidth: 46)
        }
    }

    private func controlsRow(showSpeed: Bool, volumeWidth: CGFloat) -> some View {
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

            Button(action: toggleRepeatMode) {
                Image(systemName: repeatModeIcon)
                    .font(.caption)
                    .foregroundStyle(appState.playlist.repeatMode == .none ? .secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .frame(width: 24, height: 24)
            .help(repeatModeHelpText)

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
            .frame(width: 24, height: 24)
            .help("字幕预览 (⌘S)")
            .opacity(appState.subtitlePreviewManager.items.isEmpty ? 0.35 : 1.0)
            .disabled(appState.subtitlePreviewManager.items.isEmpty)

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
                Text(String(format: "%.1fx", playerState.playbackRate))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 34)
            }
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
