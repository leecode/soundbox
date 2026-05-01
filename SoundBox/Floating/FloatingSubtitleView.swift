import SwiftUI

struct FloatingSubtitleView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var playerState: PlayerState
    @ObservedObject var manager: FloatingPanelManager

    private var subtitleText: String {
        if let currentSubtitle = playerState.currentSubtitle, !currentSubtitle.isEmpty {
            return currentSubtitle
        }
        return "♪"
    }

    private var trackTitle: String {
        appState.playlist.currentTrack?.title ?? "SoundBox"
    }

    private var progress: CGFloat {
        guard playerState.totalDuration > 0 else { return 0 }
        return CGFloat(min(max(playerState.currentTime / playerState.totalDuration, 0), 1))
    }

    var body: some View {
        VStack(spacing: manager.isHovering ? 10 : 6) {
            Text(subtitleText)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            if playerState.currentSubtitle == nil {
                Text(trackTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if manager.isHovering {
                progressBar
                    .transition(.opacity)

                controlsRow
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, manager.isHovering ? 14 : 12)
        .frame(minWidth: 220, maxWidth: 640)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .fill(manager.isDragging ? Color(nsColor: .windowBackgroundColor).opacity(0.86) : Color.clear)
                .background {
                    if !manager.isDragging {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                            .fill(.ultraThinMaterial)
                    }
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        .readSize { size in
            manager.resizeToFit(size)
        }
        .animation(.easeInOut(duration: 0.16), value: manager.isHovering)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.secondary.opacity(0.22))

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 2)
    }

    private var controlsRow: some View {
        HStack(spacing: 14) {
            Button(action: appState.goToPreviousTrack) {
                Image(systemName: "backward.fill")
            }
            .disabled(appState.playlist.previousTrack == nil)

            Button(action: appState.togglePlayback) {
                Image(systemName: playerState.playbackState.isPlaying ? "pause.fill" : "play.fill")
            }

            Button(action: appState.goToNextTrack) {
                Image(systemName: "forward.fill")
            }
            .disabled(appState.playlist.nextTrack == nil)

            Text(trackTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Button(action: manager.toggle) {
                Image(systemName: "rectangle.arrowtriangle.2.outward")
            }
            .help("关闭浮动字幕")
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(height: 24)
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private extension View {
    func readSize(_ onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}
