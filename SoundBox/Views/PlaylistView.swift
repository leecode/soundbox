import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var appState: AppState

    @State private var searchText: String = ""

    private var filteredTracks: [(offset: Int, element: Track)] {
        let enumerated = Array(appState.playlist.tracks.enumerated())
        if searchText.isEmpty { return enumerated }

        let currentIdx = appState.playlist.currentIndex
        return enumerated.filter { index, track in
            // Always keep current playing track visible
            if index == currentIdx { return true }
            return track.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("播放列表")
                    .font(.headline)
                Spacer()
                Button(action: { addFolder() }) {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.plain)
                .help("添加文件夹")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.05))

            Divider()

            // 搜索栏
            if !appState.playlist.tracks.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("搜索曲目...", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(6)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()
            }

            // 播放列表
            if appState.playlist.tracks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("空列表")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            } else {
                List(selection: $appState.playlist.currentIndex) {
                    ForEach(filteredTracks, id: \.element.id) { index, track in
                        TrackRowView(track: track, index: index, isPlaying: index == appState.playlist.currentIndex)
                            .tag(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                playTrack(at: index)
                            }
                    }
                    .onDelete { indexSet in
                        // Map filtered indices back to original playlist indices
                        let originalIndices = indexSet.map { filteredTracks[$0].offset }
                        for index in originalIndices.sorted().reversed() {
                            appState.playlist.removeTrack(at: index)
                        }
                    }
                    .onMove { source, destination in
                        guard searchText.isEmpty else { return }
                        appState.playlist.tracks.move(fromOffsets: source, toOffset: destination)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // 底部信息
            HStack {
                Text("\(appState.playlist.tracks.count) 首")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button(action: { appState.playlist.clear() }) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("清空列表")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.05))
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "选择包含音频文件的文件夹"

        if panel.runModal() == .OK {
            appState.scanAndAddFolders(panel.urls)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [appState] item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                        appState.scanAndAddFolder(url)
                    }
                }
            }
        }
    }

    private func playTrack(at index: Int) {
        appState.playlist.selectTrack(at: index)
        if let track = appState.playlist.currentTrack {
            AudioEngine.shared.loadAndPlay(track.audioFile.url)
        }
    }
}

// MARK: - Track Row View
struct TrackRowView: View {
    let track: Track
    let index: Int
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 序号/播放指示
            ZStack {
                if isPlaying {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                } else {
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                }
            }
            .frame(width: 24)

            // 曲目信息
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(isPlaying ? Color.accentColor : .primary)

                HStack(spacing: 4) {
                    if track.audioFile.format.isHiRes {
                        Text("Hi-Res")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(2)
                    }

                    Text(track.audioFile.formattedDuration)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
