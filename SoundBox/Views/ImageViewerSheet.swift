import SwiftUI
import AppKit

struct ImageViewerSheet: View {
    let url: URL
    private let presentation: ImageViewerPresentation

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var image: NSImage?
    @State private var isLoading = true
    @State private var zoomLevel: CGFloat = 1

    private let minimumZoom: CGFloat = 0.25
    private let maximumZoom: CGFloat = 6

    init(url: URL) {
        self.init(url: url, presentation: .sheet)
    }

    fileprivate init(url: URL, presentation: ImageViewerPresentation) {
        self.url = url
        self.presentation = presentation
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            ZStack {
                viewerBackground

                if let image {
                    imageCanvas(image)
                } else if isLoading {
                    ProgressView("正在载入图片...")
                        .controlSize(.small)
                } else {
                    unavailableView
                }
            }
        }
        .frame(
            minWidth: presentation == .fullScreenWindow ? 0 : 720,
            minHeight: presentation == .fullScreenWindow ? 0 : 520
        )
        .onAppear(perform: loadImage)
        .onChange(of: url) { _, _ in loadImage() }
        .onExitCommand {
            closeViewer()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .fill(.regularMaterial)
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "photo")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)

                Text(imageDetailText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                ImageViewerToolbarButton(systemName: "minus.magnifyingglass", help: "缩小", action: zoomOut)

                Slider(value: zoomBinding, in: minimumZoom...maximumZoom)
                    .frame(width: 112)
                    .help("缩放")

                ImageViewerToolbarButton(systemName: "plus.magnifyingglass", help: "放大", action: zoomIn)

                Text("\(Int(zoomLevel * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)

                ImageViewerToolbarButton(systemName: "arrow.down.right.and.arrow.up.left", help: "适应窗口", action: resetZoom)
                    .keyboardShortcut("0", modifiers: .command)
            }

            Divider()
                .frame(height: 22)

            ImageViewerToolbarButton(
                systemName: presentation == .fullScreenWindow ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                help: presentation == .fullScreenWindow ? "退出全屏" : "全屏",
                action: toggleFullScreen
            )

            Button(action: closeViewer) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("关闭")
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var viewerBackground: some View {
        Rectangle()
            .fill(colorScheme == .dark ? Color.black.opacity(0.32) : Color.primary.opacity(0.035))
    }

    private func imageCanvas(_ image: NSImage) -> some View {
        GeometryReader { proxy in
            let fittedScale = fittedScale(for: image, in: proxy.size)
            let displayScale = fittedScale * zoomLevel
            let displayWidth = max(image.size.width * displayScale, 1)
            let displayHeight = max(image.size.height * displayScale, 1)

            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: displayWidth, height: displayHeight)
                }
                    .padding(32)
                    .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
                    .contentShape(Rectangle())
                    .overlay {
                        ImageViewerDragOverlay(
                            onDoubleClick: resetZoom,
                            onMagnify: { magnification in
                                setZoom(zoomLevel * max(0.2, 1 + magnification))
                            }
                        )
                    }
            }
            .background(viewerBackground)
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)

            Text("无法显示这张图片")
                .font(.body)
                .foregroundStyle(.secondary)

            Text(url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(24)
    }

    private var imageDetailText: String {
        guard let image else { return "图片预览" }

        let dimensions = pixelDimensions(for: image)
        let size = fileSizeText(for: url)
        return [dimensions, size].compactMap { $0 }.joined(separator: " · ")
    }

    private var zoomBinding: Binding<CGFloat> {
        Binding(
            get: { zoomLevel },
            set: { setZoom($0) }
        )
    }

    private func loadImage() {
        isLoading = true
        image = nil
        resetZoom()

        ImageCache.shared.loadImage(from: url) { loadedImage in
            image = loadedImage
            isLoading = false
        }
    }

    private func fittedScale(for image: NSImage, in size: CGSize) -> CGFloat {
        guard image.size.width > 0, image.size.height > 0 else { return 1 }

        let horizontalScale = max(size.width - 64, 1) / image.size.width
        let verticalScale = max(size.height - 64, 1) / image.size.height
        return min(horizontalScale, verticalScale, 1)
    }

    private func zoomIn() {
        setZoom(zoomLevel * 1.2)
    }

    private func zoomOut() {
        setZoom(zoomLevel / 1.2)
    }

    private func resetZoom() {
        setZoom(1)
    }

    private func setZoom(_ value: CGFloat) {
        zoomLevel = min(max(value, minimumZoom), maximumZoom)
    }

    private func toggleFullScreen() {
        if presentation == .fullScreenWindow {
            NSApp.keyWindow?.toggleFullScreen(nil)
        } else {
            let fullScreenURL = url
            dismiss()
            DispatchQueue.main.async {
                ImageViewerWindowPresenter.shared.openFullScreen(url: fullScreenURL)
            }
        }
    }

    private func closeViewer() {
        if presentation == .fullScreenWindow {
            NSApp.keyWindow?.close()
        } else {
            dismiss()
        }
    }

    private func pixelDimensions(for image: NSImage) -> String? {
        guard let representation = image.representations.max(by: { $0.pixelsWide * $0.pixelsHigh < $1.pixelsWide * $1.pixelsHigh }),
              representation.pixelsWide > 0,
              representation.pixelsHigh > 0 else {
            return nil
        }

        return "\(representation.pixelsWide)×\(representation.pixelsHigh)"
    }

    private func fileSizeText(for url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = values.fileSize else {
            return nil
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}

private enum ImageViewerPresentation {
    case sheet
    case fullScreenWindow
}

@MainActor
private final class ImageViewerWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = ImageViewerWindowPresenter()

    private var windows: [NSWindow] = []

    func openFullScreen(url: URL) {
        let content = ImageViewerSheet(url: url, presentation: .fullScreenWindow)
        let hostingController = NSHostingController(rootView: content)
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let initialSize = NSSize(
            width: min(max(screenFrame.width * 0.72, 900), screenFrame.width),
            height: min(max(screenFrame.height * 0.72, 620), screenFrame.height)
        )
        let initialOrigin = NSPoint(
            x: screenFrame.midX - initialSize.width / 2,
            y: screenFrame.midY - initialSize.height / 2
        )

        let window = NSWindow(
            contentRect: NSRect(origin: initialOrigin, size: initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = url.lastPathComponent
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.contentViewController = hostingController
        window.delegate = self
        window.isReleasedWhenClosed = false

        windows.append(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            window.toggleFullScreen(nil)
        }
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            guard let closingWindow = notification.object as? NSWindow else { return }
            windows.removeAll { $0 === closingWindow }
        }
    }
}

private struct ImageViewerDragOverlay: NSViewRepresentable {
    let onDoubleClick: () -> Void
    let onMagnify: (CGFloat) -> Void

    func makeNSView(context: Context) -> DragOverlayView {
        let view = DragOverlayView()
        view.onDoubleClick = onDoubleClick
        view.onMagnify = onMagnify
        return view
    }

    func updateNSView(_ nsView: DragOverlayView, context: Context) {
        nsView.onDoubleClick = onDoubleClick
        nsView.onMagnify = onMagnify
    }
}

private final class DragOverlayView: NSView {
    var onDoubleClick: (() -> Void)?
    var onMagnify: ((CGFloat) -> Void)?

    private var lastDragLocation: NSPoint?
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let nextTrackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(nextTrackingArea)
        trackingArea = nextTrackingArea
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.openHand.set()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)

        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }

        lastDragLocation = event.locationInWindow
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let scrollView = enclosingScrollView,
              let lastDragLocation else {
            self.lastDragLocation = event.locationInWindow
            return
        }

        let currentLocation = event.locationInWindow
        let deltaX = lastDragLocation.x - currentLocation.x
        let deltaY = currentLocation.y - lastDragLocation.y
        var bounds = scrollView.contentView.bounds
        bounds.origin.x += deltaX
        bounds.origin.y += deltaY
        bounds = scrollView.contentView.constrainBoundsRect(bounds)
        scrollView.contentView.setBoundsOrigin(bounds.origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)

        self.lastDragLocation = currentLocation
    }

    override func mouseUp(with event: NSEvent) {
        lastDragLocation = nil
        NSCursor.openHand.set()
    }

    override func magnify(with event: NSEvent) {
        onMagnify?(event.magnification)
    }

    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

private struct ImageViewerToolbarButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
        .help(help)
    }
}
