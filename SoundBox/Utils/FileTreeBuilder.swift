import Foundation

class FileTreeBuilder {

    func buildTree(rootURL: URL, tracks: [Track]) -> FileTreeRoot {
        var urlToIndex: [URL: Int] = [:]
        for track in tracks {
            urlToIndex[track.audioFile.url] = track.index
        }

        let children = buildChildren(for: rootURL, urlToIndex: urlToIndex, tracks: tracks)
        let pruned = pruneEmpty(children)
        var expanded = autoExpandFirstAudioFolder(pruned)

        // Pre-compute folder metadata bottom-up
        recomputeFolderMetadata(&expanded)

        return FileTreeRoot(
            url: rootURL,
            children: expanded,
            urlToTrackIndex: urlToIndex
        )
    }

    // MARK: - Build Children

    private func buildChildren(for directory: URL, urlToIndex: [URL: Int], tracks: [Track]) -> [FileTreeNode] {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }

        var nodes: [FileTreeNode] = []

        for itemURL in contents.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
            let name = itemURL.lastPathComponent
            if name.hasPrefix(".") { continue }
            if name == "desktop.ini" { continue }

            let relativePath = itemURL.path

            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                let childNodes = buildChildren(for: itemURL, urlToIndex: urlToIndex, tracks: tracks)
                let prunedChildren = pruneEmpty(childNodes)
                if !prunedChildren.isEmpty {
                    let folder = FileTreeFolder(
                        id: relativePath,
                        name: name,
                        url: itemURL,
                        children: prunedChildren,
                        isExpanded: false,
                        containsHiRes: false,
                        fileTypeCounts: FileTypeCounts.zero
                    )
                    nodes.append(.folder(folder))
                }
            } else {
                let ext = itemURL.pathExtension.lowercased()
                if FileTypeCategory.skipExtensions.contains(ext) { continue }
                if ext.isEmpty { continue }

                let category = FileTypeCategory.classify(itemURL)

                switch category {
                case .audio:
                    let trackIndex = urlToIndex[itemURL]
                    let track = tracks.first { $0.audioFile.url == itemURL }
                    let file = FileTreeFile(
                        url: itemURL,
                        category: .audio,
                        trackIndex: trackIndex,
                        isHiRes: track?.audioFile.format.isHiRes ?? false,
                        duration: track?.audioFile.duration,
                        relativePath: relativePath
                    )
                    nodes.append(.file(file))

                case .image, .text, .video:
                    let file = FileTreeFile(
                        url: itemURL,
                        category: category,
                        relativePath: relativePath
                    )
                    nodes.append(.file(file))

                case .unknown:
                    break
                }
            }
        }

        return nodes
    }

    // MARK: - Prune Empty Folders

    private func pruneEmpty(_ nodes: [FileTreeNode]) -> [FileTreeNode] {
        nodes.compactMap { node in
            switch node {
            case .file:
                return node
            case .folder(var folder):
                let pruned = pruneEmpty(folder.children)
                if pruned.isEmpty { return nil }
                folder.children = pruned
                return .folder(folder)
            }
        }
    }

    // MARK: - Pre-compute Metadata

    private func recomputeFolderMetadata(_ nodes: inout [FileTreeNode]) {
        for i in nodes.indices {
            switch nodes[i] {
            case .file:
                break
            case .folder(var folder):
                recomputeFolderMetadata(&folder.children)
                var hiRes = false
                var counts = FileTypeCounts.zero
                for child in folder.children {
                    switch child {
                    case .file(let f):
                        if f.isHiRes { hiRes = true }
                        switch f.category {
                        case .audio: counts.audio += 1
                        case .image: counts.image += 1
                        case .text:  counts.text += 1
                        case .video: counts.video += 1
                        case .unknown: break
                        }
                    case .folder(let f):
                        if f.containsHiRes { hiRes = true }
                        counts = counts + f.fileTypeCounts
                    }
                }
                folder.containsHiRes = hiRes
                folder.fileTypeCounts = counts
                nodes[i] = .folder(folder)
            }
        }
    }

    // MARK: - Auto-Expand

    private func autoExpandFirstAudioFolder(_ nodes: [FileTreeNode]) -> [FileTreeNode] {
        var result = nodes
        expandFirstWithAudio(&result)
        return result
    }

    private func expandFirstWithAudio(_ nodes: inout [FileTreeNode]) {
        for i in nodes.indices {
            if case .folder(var folder) = nodes[i] {
                if hasAudioInChildren(folder.children) {
                    folder.isExpanded = true
                    expandFirstWithAudio(&folder.children)
                    nodes[i] = .folder(folder)
                    return
                }
            }
        }
    }

    private func hasAudioInChildren(_ nodes: [FileTreeNode]) -> Bool {
        nodes.contains {
            switch $0 {
            case .file(let f): return f.category == .audio
            case .folder: return true
            }
        }
    }
}
