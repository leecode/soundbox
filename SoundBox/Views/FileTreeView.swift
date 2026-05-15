import SwiftUI
import Quartz

// MARK: - File Tree View
struct FileTreeView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            header

            if hasContent {
                searchBar
            }

            if !hasContent {
                emptyView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    let isMulti = appState.fileTreeRoots.count > 1
                    ForEach(appState.fileTreeRoots) { root in
                        FileTreeRootView(
                            root: root,
                            isMultiRoot: isMulti,
                            searchText: searchText
                        )
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            footer
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private var hasContent: Bool {
        !appState.fileTreeRoots.isEmpty
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            if appState.fileTreeRoots.count == 1 {
                Text(appState.fileTreeRoots[0].name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            } else {
                Text("文件浏览器")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
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
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("搜索文件...", text: $searchText)
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

    // MARK: - Footer
    private var footer: some View {
        HStack(spacing: 12) {
            let counts = appState.fileTreeRoots.reduce(FileTypeCounts.zero) { $0 + $1.fileTypeCounts }
            if counts.audio > 0 {
                Label("\(counts.audio)", systemImage: "waveform")
            }
            if counts.image > 0 {
                Label("\(counts.image)", systemImage: "photo")
            }
            if counts.text > 0 {
                Label("\(counts.text)", systemImage: "doc.text")
            }
            if counts.video > 0 {
                Label("\(counts.video)", systemImage: "film")
            }
            Spacer()
            Button(action: { clearAll() }) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("清空列表")
            .disabled(!hasContent)
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
    }

    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 30))
                .foregroundStyle(.tertiary)

            Text("还没有导入作品")
                .font(.body)
                .foregroundStyle(.secondary)

            Text("添加本地文件夹后，文件会按原始目录结构展示。")
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

    // MARK: - Actions
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

    private func clearAll() {
        appState.fileTreeRoots = []
        appState.playlist.clear()
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [appState] item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        appState.scanAndAddFolder(url)
                    }
                }
            }
        }
    }
}

// MARK: - QuickLook Sheet
struct QuickLookSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)

            QuickLookPreviewItem(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct QuickLookPreviewItem: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView()
        view.autostarts = true
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as NSURL
    }
}

// MARK: - Root View
struct FileTreeRootView: View {
    let root: FileTreeRoot
    let isMultiRoot: Bool
    let searchText: String
    @State private var isExpanded: Bool = true

    var body: some View {
        if isMultiRoot {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(root.children) { node in
                    FileTreeNodeView(node: node, depth: 1, searchText: searchText)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "folder.fill" : "folder")
                        .foregroundStyle(.secondary)
                    Text(root.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
        } else {
            ForEach(root.children) { node in
                FileTreeNodeView(node: node, depth: 0, searchText: searchText)
            }
        }
    }
}

// MARK: - Node View (Recursive)
struct FileTreeNodeView: View {
    let node: FileTreeNode
    let depth: Int
    let searchText: String
    @EnvironmentObject var appState: AppState

    var body: some View {
        switch node {
        case .folder(let folder):
            FileTreeFolderView(folder: folder, depth: depth, searchText: searchText)
        case .file(let file):
            FileTreeFileRowView(file: file, depth: depth)
        }
    }
}

// MARK: - Folder View
struct FileTreeFolderView: View {
    let folder: FileTreeFolder
    let depth: Int
    let searchText: String
    @State private var isExpanded: Bool

    init(folder: FileTreeFolder, depth: Int, searchText: String) {
        self.folder = folder
        self.depth = depth
        self.searchText = searchText
        self._isExpanded = State(initialValue: folder.isExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(filteredChildren) { child in
                FileTreeNodeView(node: child, depth: depth + 1, searchText: searchText)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text(folder.name)
                    .font(.subheadline)
                    .lineLimit(1)

                if folder.containsHiRes {
                    Text("HI-RES")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                }

                Spacer()

                if folder.fileTypeCounts.total > 0 {
                    Text("\(folder.fileTypeCounts.total)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.leading, CGFloat(depth) * 8)
    }

    private var filteredChildren: [FileTreeNode] {
        if searchText.isEmpty { return folder.children }
        return folder.children.filter { nodeMatches($0, query: searchText) }
    }

    private func nodeMatches(_ node: FileTreeNode, query: String) -> Bool {
        switch node {
        case .file(let f):
            return f.displayName.localizedCaseInsensitiveContains(query)
        case .folder(let f):
            return f.name.localizedCaseInsensitiveContains(query) || f.children.contains { nodeMatches($0, query: query) }
        }
    }
}

// MARK: - File Row
struct FileTreeFileRowView: View {
    let file: FileTreeFile
    let depth: Int
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false

    var body: some View {
        Button(action: { handleTap() }) {
            HStack(spacing: 6) {
                Image(systemName: iconSystemName)
                    .font(.subheadline)
                    .foregroundStyle(iconColor)
                    .frame(width: 16)

                Text(file.displayName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(isCurrentTrack ? Color.accentColor : .primary)

                Spacer()

                if file.category == .audio {
                    if isCurrentTrack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.accentColor)
                    } else if let dur = file.duration {
                        Text(FormatUtils.formatTime(dur))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .fill(
                        isCurrentTrack
                        ? Color.accentColor.opacity(0.12)
                        : (isHovering ? Color.primary.opacity(0.07) : Color.clear)
                    )
            )
            .overlay {
                if isCurrentTrack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, CGFloat(depth) * 8 + 16)
        .onHover { isHovering = $0 }
    }

    private var isCurrentTrack: Bool {
        guard let trackIndex = file.trackIndex else { return false }
        return trackIndex == appState.playlist.currentIndex
    }

    private var iconSystemName: String {
        if file.category == .audio && isCurrentTrack {
            return "waveform"
        }
        return file.category.systemIconName
    }

    private var iconColor: Color {
        if isCurrentTrack { return .accentColor }
        return .secondary
    }

    private func handleTap() {
        switch file.category {
        case .audio:
            if let trackIndex = file.trackIndex {
                appState.playTrack(at: trackIndex)
            }
        case .image, .video:
            appState.quickLookURL = file.url
        case .text:
            appState.loadScript(from: file.url)
            appState.sidePanelActiveTab = 1
            if !appState.showSubtitlePanel {
                appState.showSubtitlePanel = true
            }
        case .unknown:
            break
        }
    }
}

// MARK: - URL Identifiable
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
