import SwiftUI

struct PlaylistView: View {
    @EnvironmentObject var appState: AppState

    @State private var searchText: String = ""

    private var filteredTracks: [(offset: Int, element: Track)] {
        let enumerated = Array(appState.playlist.tracks.enumerated())
        if searchText.isEmpty { return enumerated }

        let currentIdx = appState.playlist.currentIndex
        return enumerated.filter { index, track in
            if index == currentIdx { return true }
            return track.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("播放列表")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { addFolder() }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.body)
                }
                .buttonStyle(.plain)
                .help("添加文件夹")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

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
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            if appState.playlist.tracks.isEmpty {
                playlistEmptyView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .disabled(appState.playlist.tracks.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.04))
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private var playlistEmptyView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)

            Text("还没有音频")
                .font(.body)
                .foregroundStyle(.secondary)

            Text("添加本地文件夹后，作品会自动出现在这里。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("选择文件夹") {
                addFolder()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 2)

            Spacer()
        }
        .padding(.bottom, 16)
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
        appState.playTrack(at: index)
    }
}

// MARK: - Track Row View
struct TrackRowView: View {
    let track: Track
    let index: Int
    let isPlaying: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                AsyncArtworkView(
                    embeddedData: track.audioFile.embeddedArtworkData,
                    artworkURL: track.audioFile.artworkURL,
                    cornerRadius: DesignTokens.Radius.small
                )
                .frame(width: 36, height: 36)

                if isPlaying {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 14, height: 14)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: 0.5)
                        }
                        .offset(x: 3, y: 3)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(isPlaying ? Color.accentColor : .primary)

                HStack(spacing: 6) {
                    if track.audioFile.format.isHiRes {
                        Text("HI-RES")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                    }

                    Text(track.audioFile.formattedDuration)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }

            Spacer()

            if !isPlaying {
                Text("\(index + 1)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .fill(
                    isPlaying
                    ? Color.accentColor.opacity(0.12)
                    : (isHovering ? Color.primary.opacity(0.07) : Color.clear)
                )
        )
        .overlay {
            if isPlaying {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .contentShape(Rectangle())
    }
}
