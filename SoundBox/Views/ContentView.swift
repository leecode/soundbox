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

                    // 字幕/台本面板
                    if appState.showSubtitlePanel {
                        SidePanelView()
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

            // 书签添加浮层
            if appState.showBookmarkOverlay {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        appState.showBookmarkOverlay = false
                    }

                BookmarkOverlay(
                    timestamp: appState.playbackProgress.currentTime,
                    onSave: { label in
                        appState.addBookmarkAtCurrentPosition(label: label)
                        appState.showBookmarkOverlay = false
                    },
                    onCancel: {
                        appState.showBookmarkOverlay = false
                    }
                )
            }

            // 错误提示 toast
            if let errorMessage = appState.errorMessage {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(errorMessage)
                            .font(.body)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                    .padding(.bottom, 100)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            appState.errorMessage = nil
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Side Panel (字幕 + 台本 + 书签 标签页)
struct SidePanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SideTab = .subtitles

    enum SideTab: String, CaseIterable {
        case subtitles = "字幕"
        case script = "台本"
        case bookmarks = "书签"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏
            HStack(spacing: 0) {
                ForEach(SideTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.primary.opacity(0.05) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.primary.opacity(0.03))

            Divider()

            // 内容
            switch selectedTab {
            case .subtitles:
                SubtitlePreviewPanel(
                    subtitleManager: appState.subtitleManager,
                    subtitlePreviewManager: appState.subtitlePreviewManager,
                    currentTrackIndex: appState.playlist.currentIndex,
                    onClose: { appState.showSubtitlePanel = false },
                    onSelectSubtitle: { appState.playFromSubtitle($0) }
                )
            case .script:
                ScriptView(content: appState.scriptContent)
            case .bookmarks:
                BookmarkListView()
            }
        }
        .frame(width: 320)
        .background(.bar)
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
            // 封面图或波形占位（异步加载，优先使用内嵌封面）
            AsyncArtworkView(
                embeddedData: track.audioFile.embeddedArtworkData,
                artworkURL: track.audioFile.artworkURL
            )
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

// MARK: - Bookmark List View
struct BookmarkListView: View {
    @EnvironmentObject var appState: AppState

    private var bookmarks: [Bookmark] {
        appState.currentFileBookmarks()
    }

    var body: some View {
        VStack(spacing: 0) {
            if bookmarks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "bookmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("暂无书签")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("播放时按 ⌘B 在当前位置添加书签")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(bookmarks) { bookmark in
                        HStack(spacing: 12) {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)

                            VStack(alignment: .leading, spacing: 2) {
                                if !bookmark.label.isEmpty {
                                    Text(bookmark.label)
                                        .font(.body)
                                        .lineLimit(1)
                                }
                                Text(formatTime(bookmark.timestamp))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.seekTo(bookmark.timestamp)
                        }
                        .contextMenu {
                            Button("删除书签") {
                                appState.bookmarkManager.removeBookmark(bookmark)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
