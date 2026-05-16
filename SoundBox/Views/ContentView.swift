import SwiftUI

enum DesignTokens {
    enum Layout {
        static let sidebarWidth: CGFloat = 280
        static let sidePanelWidth: CGFloat = 320
        static let controlBarHeight: CGFloat = 80
        static let mainPadding: CGFloat = 30
        static let heroGap: CGFloat = 24
        static let heroCoverSize: CGFloat = 200
        static let compactHeroThreshold: CGFloat = 560
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
    }

    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let xlarge: CGFloat = 24
    }

    enum Slider {
        static let normalHeight: CGFloat = 4
        static let hoverHeight: CGFloat = 6
        static let bookmarkWidth: CGFloat = 2
        static let bookmarkHeight: CGFloat = 10
        static let handleSize: CGFloat = 12
        static let draggingHandleSize: CGFloat = 14
    }

    enum Colors {
        static let bookmark = Color(red: 1.0, green: 0.58, blue: 0.0)
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var updateManager: UpdateManager

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                UpdateBannerView()

                HStack(spacing: 0) {
                    FileTreeView()
                        .frame(width: DesignTokens.Layout.sidebarWidth)
                        .background(.regularMaterial)

                    Divider()

                    PlayerMainView()

                    if appState.showSubtitlePanel {
                        Divider()
                        SidePanelView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                PlayerControlBar(playerState: appState.playerState)
                    .environmentObject(appState.sleepTimerState)
                    .frame(height: DesignTokens.Layout.controlBarHeight)
                    .background(.bar)
            }

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

            if let errorMessage = appState.errorMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(errorMessage)
                            .font(.body)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
        .sheet(item: $appState.quickLookURL) { url in
            QuickLookSheet(url: url)
        }
        .task {
            if updateManager.autoCheckUpdates {
                await updateManager.checkForUpdates()
            }
        }
    }
}

// MARK: - Side Panel (字幕 + 台本 + 书签 标签页)
struct SidePanelView: View {
    @EnvironmentObject var appState: AppState

    private var selectedTab: SidePanelTab {
        appState.activeSidePanelTab
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(SidePanelTab.allCases) { tab in
                    Button(action: { appState.activeSidePanelTab = tab }) {
                        VStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: tab.iconName)
                                    .font(.caption)
                                Text(tab.label)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)

                            Rectangle()
                                .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                                .frame(height: 2)
                        }
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.label)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            switch selectedTab {
            case .subtitles:
                SubtitlePreviewPanel(
                    subtitleManager: appState.subtitleManager,
                    subtitlePreviewManager: appState.subtitlePreviewManager,
                    currentTrackIndex: appState.playlist.currentIndex,
                    currentTime: appState.playbackProgress.currentTime,
                    onClose: appState.closeSidePanel,
                    onSelectSubtitle: { appState.playFromSubtitle($0) }
                )
            case .script:
                ScriptView(content: appState.scriptContent)
            case .bookmarks:
                BookmarkListView()
            }
        }
        .frame(width: DesignTokens.Layout.sidePanelWidth)
        .background(.regularMaterial)
    }
}

// MARK: - Player Main View
struct PlayerMainView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let track = appState.playlist.currentTrack {
                    let isCompact = proxy.size.width < DesignTokens.Layout.compactHeroThreshold

                    VStack(spacing: 0) {
                        CurrentTrackHeroView(track: track, isCompact: isCompact)
                            .padding(.top, DesignTokens.Layout.mainPadding)
                            .padding(.horizontal, DesignTokens.Layout.mainPadding)

                        Spacer(minLength: 20)

                        SubtitleView()
                            .padding(.horizontal, DesignTokens.Layout.mainPadding)
                            .padding(.bottom, DesignTokens.Spacing.xlarge)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        CoverBlurBackground(track: track)
                    }
                } else {
                    EmptyStateView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Keep blur/overlay strictly inside the center column bounds.
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
                    colors: [Color.accentColor.opacity(0.08), Color.orange.opacity(0.06)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 420
                )
                .id(track.id)
                .transition(.opacity)
            }

            Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12)
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

// MARK: - Current Track Hero View
struct CurrentTrackHeroView: View {
    let track: Track
    let isCompact: Bool

    var body: some View {
        Group {
            if isCompact {
                VStack(spacing: DesignTokens.Spacing.medium) {
                    coverView
                    metaView(alignment: .center, textAlignment: .center)
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .center, spacing: DesignTokens.Layout.heroGap) {
                    coverView
                    metaView(alignment: .leading, textAlignment: .leading)
                    Spacer()
                }
            }
        }
    }

    private var coverView: some View {
        AsyncArtworkView(
            embeddedData: track.audioFile.embeddedArtworkData,
            artworkURL: track.audioFile.artworkURL,
            cornerRadius: DesignTokens.Radius.medium
        )
        .frame(width: DesignTokens.Layout.heroCoverSize, height: DesignTokens.Layout.heroCoverSize)
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
    }

    private func metaView(alignment: HorizontalAlignment, textAlignment: TextAlignment) -> some View {
        VStack(alignment: alignment, spacing: 10) {
            Text(track.title)
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(textAlignment)

            Text(track.artist ?? "未知艺术家")
                .font(.body)
                .foregroundStyle(.secondary)

            Text(track.audioFile.format.description)
                .font(.caption)
                .foregroundStyle(.tertiary)

            if track.audioFile.format.isHiRes {
                Text("HI-RES")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, DesignTokens.Spacing.small)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor.opacity(0.45), lineWidth: 1)
                    }
                    .foregroundStyle(Color.accentColor)
            }

            Text("\(track.audioFile.formattedDuration) · \(track.audioFile.formattedSize)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
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
                colors: [Color.accentColor.opacity(0.08), Color.orange.opacity(0.06), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 450
            )

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 34))
                        .foregroundStyle(.tertiary)

                    Text("开始你的离线语音库")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("导入作品目录后，SoundBox 会自动识别音频并匹配同名 VTT 字幕文件。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)

                    Button("导入作品文件夹") {
                        openFolder()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            Color.primary.opacity(colorScheme == .dark ? 0.24 : 0.14),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                }

                if !recentFolders.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最近打开")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        ForEach(Array(recentFolders.prefix(4))) { item in
                            Button(action: { openRecent(item) }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "folder")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.name)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Text(formatRecentDetail(item))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08),
                                            lineWidth: 1
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: 420)
                }

                Spacer()
            }
            .padding(30)
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
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "bookmark")
                        .font(.system(size: 34))
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
                                .foregroundStyle(DesignTokens.Colors.bookmark)
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
