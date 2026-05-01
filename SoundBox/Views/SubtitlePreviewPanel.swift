import SwiftUI

struct SubtitlePreviewPanel: View {
    @ObservedObject var subtitleManager: SubtitleManager
    @ObservedObject var subtitlePreviewManager: SubtitlePreviewManager
    let currentTrackIndex: Int
    let currentTime: TimeInterval
    let onClose: () -> Void
    let onSelectSubtitle: (SubtitlePreviewItem) -> Void

    @State private var searchText: String = ""
    @State private var expandedTrackIndices: Set<Int> = []

    var filteredItems: [SubtitlePreviewItem] {
        if searchText.isEmpty {
            return subtitlePreviewManager.items
        }
        return subtitlePreviewManager.items.filter { item in
            item.cue.text.localizedCaseInsensitiveContains(searchText) ||
            item.trackTitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredSections: [SubtitlePreviewTrackSection] {
        var sections: [SubtitlePreviewTrackSection] = []
        var sectionIndexByTrack: [Int: Int] = [:]

        for item in filteredItems {
            if let sectionIndex = sectionIndexByTrack[item.trackIndex] {
                sections[sectionIndex].items.append(item)
            } else {
                sectionIndexByTrack[item.trackIndex] = sections.count
                sections.append(SubtitlePreviewTrackSection(
                    trackIndex: item.trackIndex,
                    trackTitle: item.trackTitle,
                    items: [item]
                ))
            }
        }

        return sections
    }

    private var filteredItemIds: Set<String> {
        Set(filteredItems.map(\.id))
    }

    private var activeItem: SubtitlePreviewItem? {
        guard let activeItemId = subtitlePreviewManager.activeItemId else { return nil }
        return subtitlePreviewManager.items.first { $0.id == activeItemId }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("字幕预览")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                if !subtitlePreviewManager.items.isEmpty {
                    Text("\(subtitlePreviewManager.items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("搜索字幕...", text: $searchText)
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
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            if subtitlePreviewManager.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载中...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 34))
                        .foregroundStyle(.tertiary)

                    if searchText.isEmpty {
                        Text("暂无字幕")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        Text("播放列表中的音频文件没有关联的字幕文件")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                    } else {
                        Text("未找到匹配的字幕")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(filteredSections) { section in
                            DisclosureGroup(
                                isExpanded: bindingForSection(section.trackIndex)
                            ) {
                                ForEach(section.items) { item in
                                    SubtitleItemRow(item: item, isActive: isItemActive(item))
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            onSelectSubtitle(item)
                                        }
                                        .id(item.id)
                                }
                            } label: {
                                SubtitleTrackSectionHeader(
                                    title: section.trackTitle,
                                    count: section.items.count,
                                    isCurrent: section.trackIndex == currentTrackIndex
                                )
                            }
                            .id(section.id)
                        }
                    }
                    .listStyle(.plain)
                    .onAppear {
                        prepareActiveSubtitle(proxy: proxy)
                    }
                    .onChange(of: subtitlePreviewManager.activeItemId) { _, _ in
                        expandActiveSection()
                        scrollToActiveItem(proxy: proxy)
                    }
                    .onChange(of: currentTrackIndex) { _, _ in
                        prepareActiveSubtitle(proxy: proxy)
                    }
                    .onChange(of: searchText) { _, _ in
                        expandSectionsForSearch()
                        expandActiveSection()
                        scrollToActiveItem(proxy: proxy)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func isItemActive(_ item: SubtitlePreviewItem) -> Bool {
        return subtitlePreviewManager.activeItemId == item.id
    }

    private func bindingForSection(_ trackIndex: Int) -> Binding<Bool> {
        Binding(
            get: { expandedTrackIndices.contains(trackIndex) },
            set: { isExpanded in
                if isExpanded {
                    expandedTrackIndices.insert(trackIndex)
                } else {
                    expandedTrackIndices.remove(trackIndex)
                }
            }
        )
    }

    private func prepareActiveSubtitle(proxy: ScrollViewProxy) {
        subtitlePreviewManager.refreshActiveItem(for: currentTime, currentTrackIndex: currentTrackIndex)
        if expandedTrackIndices.isEmpty {
            expandedTrackIndices.insert(currentTrackIndex)
        }
        expandActiveSection()
        scrollToActiveItem(proxy: proxy)
    }

    private func expandActiveSection() {
        guard let activeItem else {
            expandedTrackIndices.insert(currentTrackIndex)
            return
        }
        expandedTrackIndices.insert(activeItem.trackIndex)
    }

    private func expandSectionsForSearch() {
        guard !searchText.isEmpty else { return }
        expandedTrackIndices.formUnion(filteredSections.map(\.trackIndex))
    }

    private func scrollToActiveItem(proxy: ScrollViewProxy) {
        guard let itemId = subtitlePreviewManager.activeItemId,
              filteredItemIds.contains(itemId) else {
            return
        }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(itemId, anchor: .center)
            }
        }
    }
}

private struct SubtitlePreviewTrackSection: Identifiable {
    let trackIndex: Int
    let trackTitle: String
    var items: [SubtitlePreviewItem]

    var id: String {
        "track-\(trackIndex)"
    }
}

private struct SubtitleTrackSectionHeader: View {
    let title: String
    let count: Int
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isCurrent ? "play.circle.fill" : "music.note")
                .font(.caption2)
                .foregroundStyle(isCurrent ? Color.accentColor : .secondary)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                .lineLimit(1)

            Spacer()

            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .textCase(nil)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.regularMaterial)
    }
}

// MARK: - Subtitle Item Row
struct SubtitleItemRow: View {
    let item: SubtitlePreviewItem
    let isActive: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Track title and time
            HStack {
                Text(item.trackTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isActive ? Color.accentColor : .primary)
                    .lineLimit(1)

                Spacer()

                Text(FormatUtils.formatTime(item.cue.startTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            // Subtitle text
            Text(item.cue.text)
                .font(.body)
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isActive
                    ? Color.accentColor.opacity(0.15)
                    : (isHovering ? Color.primary.opacity(0.06) : Color.clear)
                )
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    let appState = AppState()
    return SubtitlePreviewPanel(
        subtitleManager: appState.subtitleManager,
        subtitlePreviewManager: appState.subtitlePreviewManager,
        currentTrackIndex: 0,
        currentTime: 0,
        onClose: {},
        onSelectSubtitle: { _ in }
    )
    .frame(height: 600)
}
