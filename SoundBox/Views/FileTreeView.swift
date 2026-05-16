import SwiftUI
import Quartz

// MARK: - File Tree View
struct FileTreeView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var expandedNodeIDs: Set<String> = []
    @State private var loadedRootPaths: Set<String> = []

    private var visibleRows: [FileTreeVisibleRow] {
        let isMultiRoot = appState.fileTreeRoots.count > 1
        var rows: [FileTreeVisibleRow] = []

        for root in appState.fileTreeRoots {
            if isMultiRoot {
                let rootID = Self.rootRowID(for: root)
                rows.append(.folder(
                    id: rootID,
                    title: root.name,
                    depth: 0,
                    containsHiRes: false,
                    count: root.fileTypeCounts.total,
                    isRoot: true
                ))

                if searchText.isEmpty {
                    if expandedNodeIDs.contains(rootID) {
                        appendVisibleRows(from: root.children, depth: 1, to: &rows)
                    }
                } else {
                    appendSearchRows(from: root.children, depth: 1, to: &rows)
                }
            } else {
                if searchText.isEmpty {
                    appendVisibleRows(from: root.children, depth: 0, to: &rows)
                } else {
                    appendSearchRows(from: root.children, depth: 0, to: &rows)
                }
            }
        }

        return rows
    }

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
                    ForEach(visibleRows) { row in
                        switch row {
                        case .folder(let id, let title, let depth, let containsHiRes, let count, let isRoot):
                            FileTreeFolderDisclosureRow(
                                title: title,
                                depth: depth,
                                isExpanded: bindingForFolder(id),
                                containsHiRes: containsHiRes,
                                count: count,
                                isRoot: isRoot
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)

                        case .file(let file, let depth):
                            FileTreeFileRowView(file: file, depth: depth)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(ScrollWheelRouterView())
            }

            Divider()

            footer
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
        .onAppear {
            reconcileExpandedState()
        }
        .onChange(of: appState.fileTreeRoots.map(\.url)) { _, _ in
            reconcileExpandedState(force: true)
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
        expandedNodeIDs = []
        loadedRootPaths = []
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

    private func bindingForFolder(_ id: String) -> Binding<Bool> {
        Binding(
            get: {
                searchText.isEmpty ? expandedNodeIDs.contains(id) : true
            },
            set: { isExpanded in
                if isExpanded {
                    expandedNodeIDs.insert(id)
                } else {
                    expandedNodeIDs.remove(id)
                }
            }
        )
    }

    private func appendVisibleRows(from nodes: [FileTreeNode], depth: Int, to rows: inout [FileTreeVisibleRow]) {
        for node in nodes {
            switch node {
            case .folder(let folder):
                rows.append(.folder(
                    id: folder.id,
                    title: folder.name,
                    depth: depth,
                    containsHiRes: folder.containsHiRes,
                    count: folder.fileTypeCounts.total,
                    isRoot: false
                ))

                if expandedNodeIDs.contains(folder.id) {
                    appendVisibleRows(from: folder.children, depth: depth + 1, to: &rows)
                }

            case .file(let file):
                rows.append(.file(file, depth: depth))
            }
        }
    }

    private func appendSearchRows(from nodes: [FileTreeNode], depth: Int, to rows: inout [FileTreeVisibleRow]) {
        for node in nodes {
            switch node {
            case .folder(let folder):
                if folderMatchesSearch(folder) {
                    rows.append(.folder(
                        id: folder.id,
                        title: folder.name,
                        depth: depth,
                        containsHiRes: folder.containsHiRes,
                        count: folder.fileTypeCounts.total,
                        isRoot: false
                    ))
                    appendSearchRows(from: folder.children, depth: depth + 1, to: &rows)
                }

            case .file(let file):
                if file.displayName.localizedCaseInsensitiveContains(searchText) {
                    rows.append(.file(file, depth: depth))
                }
            }
        }
    }

    private func folderMatchesSearch(_ folder: FileTreeFolder) -> Bool {
        folder.name.localizedCaseInsensitiveContains(searchText) ||
        folder.children.contains { node in
            switch node {
            case .folder(let childFolder):
                return folderMatchesSearch(childFolder)
            case .file(let file):
                return file.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func reconcileExpandedState(force: Bool = false) {
        let rootPaths = Set(appState.fileTreeRoots.map(\.url.path))
        guard force || rootPaths != loadedRootPaths else { return }

        loadedRootPaths = rootPaths

        var nextExpandedIDs: Set<String> = []
        let isMultiRoot = appState.fileTreeRoots.count > 1
        for root in appState.fileTreeRoots {
            if isMultiRoot {
                nextExpandedIDs.insert(Self.rootRowID(for: root))
            }
            collectInitialExpandedIDs(from: root.children, into: &nextExpandedIDs)
        }
        expandedNodeIDs = nextExpandedIDs
    }

    private func collectInitialExpandedIDs(from nodes: [FileTreeNode], into expandedIDs: inout Set<String>) {
        for node in nodes {
            guard case .folder(let folder) = node else { continue }
            if folder.isExpanded {
                expandedIDs.insert(folder.id)
            }
            collectInitialExpandedIDs(from: folder.children, into: &expandedIDs)
        }
    }

    private static func rootRowID(for root: FileTreeRoot) -> String {
        "root:\(root.url.path)"
    }
}

private enum FileTreeVisibleRow: Identifiable {
    case folder(
        id: String,
        title: String,
        depth: Int,
        containsHiRes: Bool,
        count: Int,
        isRoot: Bool
    )
    case file(FileTreeFile, depth: Int)

    var id: String {
        switch self {
        case .folder(let id, _, _, _, _, _):
            return id
        case .file(let file, _):
            return file.id
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

// MARK: - Folder Disclosure Row
struct FileTreeFolderDisclosureRow: View {
    let title: String
    let depth: Int
    @Binding var isExpanded: Bool
    let containsHiRes: Bool
    let count: Int
    var isRoot: Bool = false
    @State private var isHovering = false

    var body: some View {
        Button(action: toggleExpanded) {
            HStack(spacing: 6) {
                DisclosureChevron(isExpanded: isExpanded)

                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(isRoot ? .medium : .regular)
                    .lineLimit(1)

                if containsHiRes {
                    Text("HI-RES")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                }

                Spacer(minLength: 8)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .padding(.leading, CGFloat(depth) * 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                    .fill(isHovering ? Color.primary.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, isRoot ? 12 : 0)
        .onHover { isHovering = $0 }
        .accessibilityLabel(title)
        .accessibilityValue(isExpanded ? "已展开" : "已折叠")
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.14)) {
            isExpanded.toggle()
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
            appState.openSidePanel(.script)
        case .unknown:
            break
        }
    }
}

// MARK: - URL Identifiable
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
