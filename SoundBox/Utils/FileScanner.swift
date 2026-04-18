import Foundation
import AVFoundation

// MARK: - File Scanner
class FileScanner {

    // MARK: - Supported Extensions
    private var audioExtensions: [String] { LosslessDecoder.supportedExtensions }
    private let subtitleExtensions = ["vtt", "srt"]
    private let scriptExtensions = ["txt"]

    // Cap concurrent metadata reads to avoid disk thrashing on large files
    private let metadataConcurrencyLimit = 4
    private let metadataSemaphore = DispatchSemaphore(value: 4)

    // MARK: - Scan Directory
    func scanDirectory(_ url: URL, completion: @escaping ([Track]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            var tracks: [Track] = []
            var index = 0

            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            var audioFiles: [(URL, URL?, URL?)] = []

            for case let fileURL as URL in enumerator {
                let ext = fileURL.pathExtension.lowercased()

                if self.audioExtensions.contains(ext) {
                    let subtitleURL = self.findSubtitleFile(for: fileURL)
                    let scriptURL = self.findScriptFile(for: fileURL)
                    audioFiles.append((fileURL, subtitleURL, scriptURL))
                }
            }

            // Sort by track number in filename
            audioFiles.sort { file1, file2 in
                let name1 = file1.0.deletingPathExtension().lastPathComponent
                let name2 = file2.0.deletingPathExtension().lastPathComponent
                let num1 = self.extractTrackNumber(from: name1)
                let num2 = self.extractTrackNumber(from: name2)

                if let n1 = num1, let n2 = num2 {
                    return n1 < n2
                }
                return name1 < name2
            }

            let artworkURL = self.findArtworkFile(in: url)

            let group = DispatchGroup()
            let syncQueue = DispatchQueue(label: "com.soundbox.scanner.sync", qos: .userInitiated)

            for (audioURL, subtitleURL, scriptURL) in audioFiles {
                group.enter()
                let currentIndex = index
                index += 1
                self.createTrack(from: audioURL, subtitleURL: subtitleURL, artworkURL: artworkURL, scriptURL: scriptURL, index: currentIndex) { track in
                    syncQueue.sync {
                        if let track = track {
                            tracks.append(track)
                        }
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                let sortedTracks = tracks.sorted { $0.index < $1.index }
                completion(sortedTracks)
            }
        }
    }

    // MARK: - Find Artwork File
    private func findArtworkFile(in directory: URL) -> URL? {
        let imageExtensions = Set(["jpg", "jpeg", "png", "webp"])
        let preferredNames = ["cover", "folder", "album", "artwork", "front"]

        // First pass: look for preferred filenames (cover.jpg, folder.png, etc.)
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var allImages: [URL] = []

        for case let fileURL as URL in enumerator {
            if imageExtensions.contains(fileURL.pathExtension.lowercased()) {
                let nameWithoutExt = fileURL.deletingPathExtension().lastPathComponent.lowercased()
                if preferredNames.contains(nameWithoutExt) {
                    return fileURL  // Found a preferred artwork file
                }
                allImages.append(fileURL)
            }
        }

        // Fallback: return first image found
        return allImages.first
    }

    // MARK: - Find Subtitle File
    private func findSubtitleFile(for audioURL: URL) -> URL? {
        let baseName = audioURL.deletingPathExtension().lastPathComponent
        let fullName = audioURL.lastPathComponent

        for subExt in subtitleExtensions {
            // Try full filename + extension (e.g., track.wav.vtt)
            let subPath1 = audioURL.deletingLastPathComponent()
                .appendingPathComponent(fullName + "." + subExt)
            if FileManager.default.fileExists(atPath: subPath1.path) {
                return subPath1
            }

            // Try base name (e.g., track.vtt)
            let subPath2 = audioURL.deletingLastPathComponent()
                .appendingPathComponent(baseName + "." + subExt)
            if FileManager.default.fileExists(atPath: subPath2.path) {
                return subPath2
            }
        }
        return nil
    }

    // MARK: - Find Script File
    private func findScriptFile(for audioURL: URL) -> URL? {
        let baseName = audioURL.deletingPathExtension().lastPathComponent

        for scriptExt in scriptExtensions {
            let scriptPath = audioURL.deletingLastPathComponent()
                .appendingPathComponent(baseName + "." + scriptExt)
            if FileManager.default.fileExists(atPath: scriptPath.path) {
                return scriptPath
            }
        }
        return nil
    }

    // MARK: - Create Track
    private func createTrack(from url: URL, subtitleURL: URL?, artworkURL: URL?, scriptURL: URL?, index: Int, completion: @escaping (Track?) -> Void) {
        let decoder = LosslessDecoder()
        decoder.getAudioInfo(url) { result in
            switch result {
            case .success(let info):
                // Read embedded metadata in parallel (AVAsset on background thread)
                self.metadataSemaphore.wait()
                let asset = AVAsset(url: url)
                var embeddedTitle: String?
                var embeddedArtist: String?
                var embeddedAlbum: String?
                var embeddedArtworkData: Data?

                for item in asset.commonMetadata {
                    if item.commonKey == .commonKeyTitle {
                        embeddedTitle = item.stringValue
                    } else if item.commonKey == .commonKeyArtist {
                        embeddedArtist = item.stringValue
                    } else if item.commonKey == .commonKeyAlbumName {
                        embeddedAlbum = item.stringValue
                    } else if item.commonKey == .commonKeyArtwork {
                        embeddedArtworkData = item.dataValue
                    }
                }
                self.metadataSemaphore.signal()

                let audioFile = AudioFile(
                    url: url,
                    format: info.audioFormat,
                    duration: info.duration,
                    subtitleURL: subtitleURL,
                    artworkURL: artworkURL,
                    scriptURL: scriptURL,
                    embeddedTitle: embeddedTitle,
                    embeddedArtist: embeddedArtist,
                    embeddedAlbum: embeddedAlbum,
                    embeddedArtworkData: embeddedArtworkData
                )

                let track = Track(
                    audioFile: audioFile,
                    index: index,
                    title: embeddedTitle ?? url.deletingPathExtension().lastPathComponent,
                    artist: embeddedArtist,
                    album: embeddedAlbum
                )
                completion(track)

            case .failure:
                completion(nil)
            }
        }
    }

    // MARK: - Check if Audio File
    func isAudioFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return audioExtensions.contains(ext)
    }

    // MARK: - Extract Track Number
    private func extractTrackNumber(from filename: String) -> Int? {
        // Match #N format (e.g., #1, #10, #01)
        let hashPattern = "#(\\d+)"
        if let range = filename.range(of: hashPattern, options: .regularExpression),
           let numberRange = Range(NSRange(range, in: filename), in: filename) {
            let numberString = filename[numberRange].dropFirst()
            return Int(numberString)
        }

        // Match leading digits (e.g., 01., 01-, 1_)
        let leadingPattern = "^(\\d+)[.\\-_\\s]"
        if let range = filename.range(of: leadingPattern, options: .regularExpression),
           let numberRange = Range(NSRange(range, in: filename), in: filename) {
            let numberString = filename[numberRange]
            let digits = numberString.dropLast()
            return Int(digits)
        }

        // Match brackets (e.g., (01), [01])
        let bracketPattern = "[\\[\\(](\\d+)[\\]\\)]"
        if let range = filename.range(of: bracketPattern, options: .regularExpression) {
            let substring = String(filename[range])
            let digits = substring.filter { $0.isNumber }
            return Int(digits)
        }

        return nil
    }
}
