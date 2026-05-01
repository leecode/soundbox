import AppKit
import Combine
import SwiftUI

final class FloatingSubtitlePanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 132),
            styleMask: [.nonactivatingPanel, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }
}

final class FloatingSubtitleHostingView: NSHostingView<FloatingSubtitleView> {
    weak var floatingPanelManager: FloatingPanelManager?
    private var didStartDrag = false

    override func mouseDown(with event: NSEvent) {
        didStartDrag = false
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let floatingPanelManager else {
            super.mouseDragged(with: event)
            return
        }

        if !didStartDrag {
            floatingPanelManager.beginDragging()
            didStartDrag = true
        }
        floatingPanelManager.updateDragPosition()
    }

    override func mouseUp(with event: NSEvent) {
        if didStartDrag {
            floatingPanelManager?.updateDragPosition(force: true)
            floatingPanelManager?.endDragging()
            didStartDrag = false
        }
        super.mouseUp(with: event)
    }
}

final class FloatingPanelManager: ObservableObject {
    @Published var isEnabled = false
    @Published var isVisible = false
    @Published var isHovering = false
    @Published private(set) var isDragging = false

    private weak var appState: AppState?
    private var panel: FloatingSubtitlePanel?
    private var cancellables = Set<AnyCancellable>()
    private var mouseMonitor: Any?
    private var appActivationObserver: NSObjectProtocol?
    private var focusUpdateTask: DispatchWorkItem?
    private var soundBoxIsFrontmost = true
    private var dragOffsetFromPanelOrigin: CGSize?
    private var lastFittedSize: CGSize = .zero
    private var lastDragOrigin: NSPoint?
    private var lastDragUpdateTime: TimeInterval = 0
    private var pendingResizeSize: CGSize?
    private var resizeWorkItem: DispatchWorkItem?
    private let dragUpdateInterval: TimeInterval = 1.0 / 60.0

    deinit {
        if let mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        if let appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver)
        }
    }

    func configure(appState: AppState) {
        guard self.appState == nil else { return }

        self.appState = appState
        createPanel(appState: appState)
        restorePanelPosition()
        setupActivationObserver()
        setupMouseMonitor()
        bindAppState(appState)
        updateFrontmostState()
        refreshVisibility()
    }

    func toggle() {
        setEnabled(!isEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        refreshVisibility()
    }

    func beginDragging() {
        guard let panel else { return }
        if !isDragging {
            isDragging = true
            applyDraggingWindowAppearance(true)
        }
        panel.ignoresMouseEvents = false

        if dragOffsetFromPanelOrigin == nil {
            let mouseLocation = NSEvent.mouseLocation
            dragOffsetFromPanelOrigin = CGSize(
                width: mouseLocation.x - panel.frame.origin.x,
                height: mouseLocation.y - panel.frame.origin.y
            )
        }
    }

    func updateDragPosition(force: Bool = false) {
        guard let panel, let dragOffsetFromPanelOrigin else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if !force, now - lastDragUpdateTime < dragUpdateInterval {
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: mouseLocation.x - dragOffsetFromPanelOrigin.width,
            y: mouseLocation.y - dragOffsetFromPanelOrigin.height
        )
        if let lastDragOrigin,
           abs(lastDragOrigin.x - newOrigin.x) < 0.5,
           abs(lastDragOrigin.y - newOrigin.y) < 0.5 {
            return
        }

        lastDragOrigin = newOrigin
        lastDragUpdateTime = now
        panel.setFrameOrigin(newOrigin)
    }

    func endDragging() {
        if isDragging {
            isDragging = false
            applyDraggingWindowAppearance(false)
        }
        dragOffsetFromPanelOrigin = nil
        lastDragOrigin = nil
        lastDragUpdateTime = 0
        panel?.ignoresMouseEvents = !isHovering
        savePanelPosition()
    }

    private func applyDraggingWindowAppearance(_ dragging: Bool) {
        guard let panel else { return }
        if dragging {
            panel.isOpaque = true
            panel.backgroundColor = .windowBackgroundColor
        } else {
            panel.isOpaque = false
            panel.backgroundColor = .clear
        }
    }

    func resizeToFit(_ size: CGSize) {
        pendingResizeSize = size
        guard resizeWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.resizeWorkItem = nil
            guard let size = self.pendingResizeSize else { return }
            self.pendingResizeSize = nil
            self.applyResizeToFit(size)
        }
        resizeWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func applyResizeToFit(_ size: CGSize) {
        guard let panel else { return }
        guard !isDragging else { return }
        let width = min(max(size.width, 220), 640)
        let height = min(max(size.height, 82), 220)
        let fittedSize = CGSize(width: width, height: height)
        guard abs(fittedSize.width - lastFittedSize.width) > 0.5 ||
              abs(fittedSize.height - lastFittedSize.height) > 0.5 else { return }

        lastFittedSize = fittedSize
        let oldFrame = panel.frame
        let newFrame = NSRect(
            x: oldFrame.midX - width / 2,
            y: oldFrame.maxY - height,
            width: width,
            height: height
        )
        panel.setFrame(newFrame, display: true, animate: false)
    }

    private func createPanel(appState: AppState) {
        let panel = FloatingSubtitlePanel()
        let hostingView = FloatingSubtitleHostingView(
            rootView: FloatingSubtitleView(
                appState: appState,
                playerState: appState.playerState,
                manager: self
            )
        )
        hostingView.floatingPanelManager = self
        panel.contentView = hostingView
        self.panel = panel
    }

    private func bindAppState(_ appState: AppState) {
        appState.playlist.$tracks
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshVisibility()
                }
            }
            .store(in: &cancellables)

        appState.playlist.$currentIndex
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshVisibility()
                }
            }
            .store(in: &cancellables)

        appState.playerState.$playbackState
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshVisibility()
                }
            }
            .store(in: &cancellables)
    }

    private func setupActivationObserver() {
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleFocusRefresh()
        }
    }

    private func setupMouseMonitor() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateHoverState(mouseLocation: NSEvent.mouseLocation)
            }
        }
    }

    private func scheduleFocusRefresh() {
        focusUpdateTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            self?.updateFrontmostState()
            self?.refreshVisibility()
        }
        focusUpdateTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }

    private func updateFrontmostState() {
        let currentBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        soundBoxIsFrontmost = currentBundleID == Bundle.main.bundleIdentifier
    }

    private func updateHoverState(mouseLocation: NSPoint) {
        guard !isDragging else { return }
        guard let panel, isVisible else {
            isHovering = false
            return
        }

        let hoverFrame = panel.frame.insetBy(dx: -8, dy: -8)
        let hovering = hoverFrame.contains(mouseLocation)
        if hovering != isHovering {
            withAnimation(.easeInOut(duration: 0.16)) {
                isHovering = hovering
            }
        }
        panel.ignoresMouseEvents = !(hovering || isDragging)
    }

    private func refreshVisibility() {
        guard let appState, let panel else { return }
        let hasPlayableTrack = appState.playlist.currentTrack != nil
        let canShowForPlayback = appState.playerState.playbackState == .playing || appState.playerState.playbackState == .paused
        let shouldShow = isEnabled && !soundBoxIsFrontmost && hasPlayableTrack && canShowForPlayback

        if shouldShow {
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        } else {
            panel.orderOut(nil)
            isHovering = false
            panel.ignoresMouseEvents = true
        }

        if isVisible != shouldShow {
            isVisible = shouldShow
        }
    }

    private func defaultPanelFrame() -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 680)
        let size = NSSize(width: 520, height: 132)
        return NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.minY + 20,
            width: size.width,
            height: size.height
        )
    }

    private func restorePanelPosition() {
        guard let panel else { return }
        let defaults = UserDefaults.standard
        let x = defaults.double(forKey: "floatingPanelPositionX")
        let y = defaults.double(forKey: "floatingPanelPositionY")
        if x != 0 || y != 0 {
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.setFrame(defaultPanelFrame(), display: false)
        }
    }

    private func savePanelPosition() {
        guard let panel else { return }
        UserDefaults.standard.set(panel.frame.origin.x, forKey: "floatingPanelPositionX")
        UserDefaults.standard.set(panel.frame.origin.y, forKey: "floatingPanelPositionY")
    }
}
