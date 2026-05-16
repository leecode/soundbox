import AppKit
import SwiftUI

struct ScrollWheelRouterView: NSViewRepresentable {
    func makeNSView(context: Context) -> RoutingView {
        RoutingView()
    }

    func updateNSView(_ nsView: RoutingView, context: Context) {}

    final class RoutingView: NSView {
        private var scrollMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateMonitor()
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        deinit {
            removeMonitor()
        }

        private func updateMonitor() {
            removeMonitor()

            guard window != nil else { return }

            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.route(event) ?? event
            }
        }

        private func removeMonitor() {
            if let scrollMonitor {
                NSEvent.removeMonitor(scrollMonitor)
                self.scrollMonitor = nil
            }
        }

        private func route(_ event: NSEvent) -> NSEvent? {
            guard isEventInsideView(event),
                  let scrollView = targetScrollView(for: event) else {
                return event
            }

            scrollView.scrollWheel(with: event)
            return nil
        }

        private func isEventInsideView(_ event: NSEvent) -> Bool {
            guard window === event.window else { return false }
            let point = convert(event.locationInWindow, from: nil)
            return bounds.contains(point)
        }

        private func targetScrollView(for event: NSEvent) -> NSScrollView? {
            guard let contentView = window?.contentView else { return nil }

            let eventLocation = event.locationInWindow
            let routerFrame = convert(bounds, to: nil)
            var bestMatch: (scrollView: NSScrollView, overlap: CGFloat)?

            for scrollView in contentView.recursiveSubviews(ofType: NSScrollView.self) {
                let scrollFrame = scrollView.convert(scrollView.bounds, to: nil)
                guard scrollFrame.contains(eventLocation), scrollFrame.intersects(routerFrame) else {
                    continue
                }

                let overlap = scrollFrame.intersection(routerFrame).area
                if bestMatch == nil || overlap > bestMatch!.overlap {
                    bestMatch = (scrollView, overlap)
                }
            }

            return bestMatch?.scrollView
        }
    }
}

private extension NSView {
    func recursiveSubviews<T: NSView>(ofType type: T.Type) -> [T] {
        var matches: [T] = []

        for subview in subviews {
            if let match = subview as? T {
                matches.append(match)
            }
            matches.append(contentsOf: subview.recursiveSubviews(ofType: type))
        }

        return matches
    }
}

private extension NSRect {
    var area: CGFloat {
        width * height
    }
}
