import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            // 背景
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 主内容区
                HStack(spacing: 0) {
                    // 左侧：播放列表
                    PlaylistView()
                        .frame(width: 280)
                        .background(Color.primary.opacity(0.05))

                    // 分隔线
                    Divider()

                    // 字幕预览面板
                    if appState.showSubtitlePanel {
                        SubtitlePreviewPanel(
                            subtitleManager: appState.subtitleManager,
                            subtitlePreviewManager: appState.subtitlePreviewManager,
                            currentTrackIndex: appState.playlist.currentIndex,
                            onClose: { appState.showSubtitlePanel = false },
                            onSelectSubtitle: { appState.playFromSubtitle($0) }
                        )
                        Divider()
                    }

                    // 右侧：播放器主界面
                    PlayerMainView()
                }

                // 底部：播放控制栏
                PlayerControlBar(playerState: appState.playerState)
                    .frame(height: 80)
                    .background(.bar)
            }
        }
    }
}

// MARK: - Player Main View
struct PlayerMainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            if let track = appState.playlist.currentTrack {
                // 当前播放信息
                CurrentTrackView(track: track)

                // 字幕显示
                SubtitleView()
            } else {
                // 空状态
                EmptyStateView()
            }

            Spacer()
        }
        .padding(30)
    }
}

// MARK: - Current Track View
struct CurrentTrackView: View {
    let track: Track

    var body: some View {
        VStack(spacing: 12) {
            // 封面图或波形占位
            Group {
                if let artworkURL = track.audioFile.artworkURL,
                   let nsImage = NSImage(contentsOf: artworkURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Image(systemName: "waveform")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 200, height: 200)

            // 音频格式信息
            HStack(spacing: 8) {
                if track.audioFile.format.isHiRes {
                    Text("Hi-Res")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }

                Text(track.audioFile.format.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(track.title)
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if let artist = track.artist {
                Text(artist)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Text("\(track.audioFile.formattedDuration) · \(track.audioFile.formattedSize)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)

            Text("SoundBox")
                .font(.title)
                .fontWeight(.bold)

            Text("高保真音频播放器")
                .foregroundStyle(.secondary)

            Text("拖放音频文件到此处，或使用菜单打开文件夹")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("选择文件夹") {
                openFolder()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "选择包含音频文件的文件夹"

        if panel.runModal() == .OK {
            appState.scanAndAddFolders(panel.urls)
        }
    }
}
