import Foundation

// MARK: - File Scanner
class FileScanner {

    // MARK: - Supported Audio Extensions
    private let audioExtensions = ["wav", "flac", "aiff", "aif", "alac", "m4a", "aac", "mp3", "ogg"]
    private let subtitleExtensions = ["vtt", "srt"]

    // MARK: - Scan Directory
    func scanDirectory(_ url: URL, completion: @escaping ([Track]) -> Void) {
        print("📁 开始扫描目录: \(url.path)")

        DispatchQueue.global(qos: .userInitiated).async {
            var tracks: [Track] = []
            var index = 0

            // 获取目录下所有文件
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                print("❌ 无法创建文件枚举器")
                DispatchQueue.main.async { completion([]) }
                return
            }

            var audioFiles: [(URL, URL?)] = [] // (audioURL, subtitleURL)
            var fileCount = 0

            for case let fileURL as URL in enumerator {
                fileCount += 1
                let ext = fileURL.pathExtension.lowercased()

                if self.audioExtensions.contains(ext) {
                    print("🎵 发现音频文件: \(fileURL.lastPathComponent)")
                    // 查找对应的字幕文件
                    let baseName = fileURL.deletingPathExtension().lastPathComponent
                    var subtitleURL: URL? = nil

                    for subExt in self.subtitleExtensions {
                        let subPath = fileURL.deletingLastPathComponent()
                            .appendingPathComponent(baseName + "." + subExt)
                        if FileManager.default.fileExists(atPath: subPath.path) {
                            subtitleURL = subPath
                            print("📝 发现字幕文件: \(subPath.lastPathComponent)")
                            break
                        }
                    }

                    audioFiles.append((fileURL, subtitleURL))
                }
            }

            print("📊 扫描完成: 共 \(fileCount) 个文件, \(audioFiles.count) 个音频文件")

            // 按文件名排序
            audioFiles.sort { $0.0.lastPathComponent < $1.0.lastPathComponent }

            // 使用 DispatchGroup 同步处理每个文件
            let group = DispatchGroup()
            let syncQueue = DispatchQueue(label: "com.soundbox.scanner.sync", qos: .userInitiated)
            var successCount = 0
            var failCount = 0

            for (audioURL, subtitleURL) in audioFiles {
                group.enter()
                let currentIndex = index
                index += 1
                self.createTrack(from: audioURL, subtitleURL: subtitleURL, index: currentIndex) { track in
                    syncQueue.sync {
                        if let track = track {
                            tracks.append(track)
                            successCount += 1
                        } else {
                            failCount += 1
                        }
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                print("✅ 处理完成: 成功 \(successCount) 个, 失败 \(failCount) 个")
                // 按索引排序
                let sortedTracks = tracks.sorted { $0.index < $1.index }
                completion(sortedTracks)
            }
        }
    }

    // MARK: - Create Track
    private func createTrack(from url: URL, subtitleURL: URL?, index: Int, completion: @escaping (Track?) -> Void) {
        let decoder = LosslessDecoder()
        decoder.getAudioInfo(url) { result in
            switch result {
            case .success(let info):
                let audioFile = AudioFile(
                    url: url,
                    format: info.audioFormat,
                    duration: info.duration,
                    subtitleURL: subtitleURL
                )

                let track = Track(
                    audioFile: audioFile,
                    index: index,
                    title: url.deletingPathExtension().lastPathComponent
                )
                print("✅ 创建 Track 成功: \(track.title)")
                completion(track)

            case .failure(let error):
                print("❌ 创建 Track 失败 \(url.lastPathComponent): \(error)")
                completion(nil)
            }
        }
    }

    // MARK: - Check if Audio File
    func isAudioFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return audioExtensions.contains(ext)
    }
}
