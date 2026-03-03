import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 主内容区
                HStack(spacing: 0) {
                    // 左侧：播放列表
                    PlaylistView()
                        .frame(width: 280)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                    // 分隔线
                    Divider()

                    // 右侧：播放器主界面
                    PlayerMainView()
                }

                // 底部：播放控制栏
                PlayerControlBar()
                    .frame(height: 80)
                    .background(Color(nsColor: .windowBackgroundColor))
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

                // 波形可视化（预留）
                WaveformView()

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
            // 封面占位（可以显示专辑封面）
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .overlay {
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                }

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

// MARK: - Waveform View (预留)
struct WaveformView: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<50, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: 3, height: CGFloat.random(in: 10...40))
            }
        }
        .frame(height: 60)
        .opacity(0.5)
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
        print("🖱️ openFolder() 被调用")
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择包含音频文件的文件夹"

        let result = panel.runModal()
        print("🖱️ Panel result: \(result.rawValue), OK=\(NSApplication.ModalResponse.OK.rawValue)")

        if result == .OK {
            if let url = panel.url {
                print("🖱️ 选择的文件夹: \(url.path)")
                scanDirectory(url)
            } else {
                print("🖱️ 没有获取到 URL!")
            }
        } else {
            print("🖱️ 用户取消了选择")
        }
    }

    private func scanDirectory(_ url: URL) {
        // 扫描目录并添加到播放列表
        print("📂 scanDirectory 被调用: \(url.path)")
        let scanner = FileScanner()
        scanner.scanDirectory(url) { tracks in
            print("📋 扫描完成回调执行，获取到 \(tracks.count) 个曲目")
            DispatchQueue.main.async {
                print("📋 准备添加曲目到播放列表...")
                print("📋 添加前 appState.playlist.tracks.count = \(self.appState.playlist.tracks.count)")
                self.appState.playlist.addTracks(tracks)
                print("📋 添加后 appState.playlist.tracks.count = \(self.appState.playlist.tracks.count)")
            }
        }
    }
}
