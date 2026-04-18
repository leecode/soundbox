import SwiftUI

/// NSCache-based image loader. Loads from embedded Data or external URL asynchronously.
/// Replaces the sync `NSImage(contentsOf:)` pattern that was blocking the main thread.
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 100
    }

    /// Synchronous cache lookup. Returns nil if not cached (caller should trigger async load).
    func cachedImage(key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    /// Load image from embedded Data. Returns immediately if cached, otherwise loads and calls back.
    func loadImage(from data: Data, key: String, completion: @escaping (NSImage?) -> Void) {
        if let cached = cachedImage(key: key) {
            completion(cached)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image = NSImage(data: data)
            if let image {
                self?.cache.setObject(image, forKey: key as NSString)
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    /// Load image from file URL. Returns immediately if cached, otherwise loads and calls back.
    func loadImage(from url: URL, completion: @escaping (NSImage?) -> Void) {
        let key = url.absoluteString

        if let cached = cachedImage(key: key) {
            completion(cached)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image = NSImage(contentsOf: url)
            if let image {
                self?.cache.setObject(image, forKey: key as NSString)
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    func clear() {
        cache.removeAllObjects()
    }
}

/// SwiftUI view that loads artwork asynchronously with placeholder.
/// Resolves priority: embedded artwork data > external image file > placeholder.
struct AsyncArtworkView: View {
    let embeddedData: Data?
    let artworkURL: URL?
    let cornerRadius: CGFloat

    @State private var image: NSImage?

    init(embeddedData: Data?, artworkURL: URL?, cornerRadius: CGFloat = 12) {
        self.embeddedData = embeddedData
        self.artworkURL = artworkURL
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "waveform")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .onAppear { loadArtwork() }
        .onChange(of: embeddedData?.count) { _, _ in loadArtwork() }
        .onChange(of: artworkURL) { _, _ in loadArtwork() }
    }

    private func loadArtwork() {
        // Priority: embedded data > external URL
        if let data = embeddedData {
            ImageCache.shared.loadImage(from: data, key: "embedded-\(data.hashValue)") { img in
                self.image = img
            }
        } else if let url = artworkURL {
            ImageCache.shared.loadImage(from: url) { img in
                self.image = img
            }
        } else {
            image = nil
        }
    }
}
