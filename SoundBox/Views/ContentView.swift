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

                    Divider()

                    // 中间：播放器主界面
                    PlayerMainView()

                    // 右侧：字幕/台本面板
                    if appState.showSubtitlePanel {
                        Divider()
                        SidePanelView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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

        var iconName: String {
            switch self {
            case .subtitles: return "text.bubble"
            case .script: return "doc.text"
            case .bookmarks: return "bookmark"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标签栏 (图标)
            HStack(spacing: 0) {
                ForEach(SideTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 0) {
                            Image(systemName: tab.iconName)
                                .font(.body)
                                .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)

                            Rectangle()
                                .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.rawValue)
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
        VStack(spacing: 16) {
            GeometryReader { geo in
                if let track = appState.playlist.currentTrack {
                    VStack(spacing: 8) {
                        CurrentTrackView(track: track, maxHeight: geo.size.height)
                        SubtitleView()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyStateView()
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if let track = appState.playlist.currentTrack {
                CoverBlurBackground(track: track)
            }
        }
        .clipped()
    }
}

// MARK: - Cover Art Blur Background
struct CoverBlurBackground: View {
    let track: Track
    @State private var image: NSImage?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 60)
                    .opacity(colorScheme == .dark ? 0.6 : 0.4)
                    .id(track.id)
                    .transition(.opacity)
            } else {
                RadialGradient(
                    colors: [Color.accentColor.opacity(0.03), Color.orange.opacity(0.02)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 300
                )
                .id(track.id)
                .transition(.opacity)
            }

            Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1)
        }
        .clipped()
        .animation(.easeInOut, value: track.id)
        .onAppear { loadImage() }
        .onChange(of: track.id) { _, _ in loadImage() }
    }

    private func loadImage() {
        image = nil
        if let data = track.audioFile.embeddedArtworkData {
            ImageCache.shared.loadImage(from: data, key: "embedded-\(data.hashValue)") { img in
                withAnimation(.easeInOut) { self.image = img }
            }
        } else if let url = track.audioFile.artworkURL {
            ImageCache.shared.loadImage(from: url) { img in
                withAnimation(.easeInOut) { self.image = img }
            }
        }
    }
}

// MARK: - Current Track View
struct CurrentTrackView: View {
    let track: Track
    var maxHeight: CGFloat = .infinity

    private var coverSize: CGFloat {
        min(200, maxHeight * 0.35)
    }

    var body: some View {
        VStack(spacing: 12) {
            AsyncArtworkView(
                embeddedData: track.audioFile.embeddedArtworkData,
                artworkURL: track.audioFile.artworkURL
            )
            .frame(width: coverSize, height: coverSize)
            .shadow(color: .black.opacity(0.4), radius: 16, y: 8)

            // 音频格式信息
            HStack(spacing: 8) {
                if track.audioFile.format.isHiRes {
                    Text("Hi-Res")
                        .font(.system(size: 9))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor)
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
    @Environment(\.colorScheme) private var colorScheme

    private var recentFolders: [FolderHistoryItem] {
        appState.folderHistoryManager.items.filter {
            appState.folderHistoryManager.itemExists(at: $0.url)
        }
    }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.03 : 0.04),
                    Color.orange.opacity(colorScheme == .dark ? 0.02 : 0.03)
                ],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
        }
        .ignoresSafeArea()

        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
                .opacity(0.6)
                .frame(width: 80, height: 80)
                .background(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("打开音声作品")
                .font(.title2)
                .fontWeight(.semibold)

            Text("选择一个包含音频文件的文件夹，开始播放")
                .font(.body)
                .foregroundStyle(.secondary)

            Button("选择文件夹…") {
                openFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("或拖拽文件夹到此窗口")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if !recentFolders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近打开")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)

                    ForEach(Array(recentFolders.prefix(5))) { item in
                        Button(action: { openRecent(item) }) {
                            HStack(spacing: 10) {
                                Image(systemName: "folder")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32, height: 32)
                                    .background(Color.primary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Text(formatRecentDetail(item))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 320)
                .padding(.top, 12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func openRecent(_ item: FolderHistoryItem) {
        guard appState.folderHistoryManager.itemExists(at: item.url) else { return }
        appState.scanAndAddFolder(item.url)
    }

    private func formatRecentDetail(_ item: FolderHistoryItem) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        return "上次播放 \(formatter.string(from: item.lastOpenedAt))"
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
                                Text(FormatUtils.formatTime(bookmark.timestamp))
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
}
