import Foundation
import AppKit

// MARK: - Models

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let htmlUrl: String
    let body: String?
    let assets: [GitHubAsset]

    var dmgAsset: GitHubAsset? {
        assets.first { $0.name.lowercased().hasSuffix(".dmg") }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlUrl = "html_url"
        case body
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

// MARK: - Version Comparison

func parseVersion(_ version: String) -> (Int, Int, Int) {
    let cleaned = version
        .replacingOccurrences(of: "v", with: "", options: .anchored)
        .components(separatedBy: "-").first ?? version
    let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        .compactMap { Int($0) }
    guard parts.count >= 3 else {
        return (parts.count > 0 ? parts[0] : 0,
                parts.count > 1 ? parts[1] : 0,
                parts.count > 2 ? parts[2] : 0)
    }
    return (parts[0], parts[1], parts[2])
}

func isNewerVersion(_ remote: String, than local: String) -> Bool {
    let r = parseVersion(remote)
    let l = parseVersion(local)
    return r > l
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}

// MARK: - UpdateManager

@MainActor
class UpdateManager: ObservableObject {
    @Published var updateAvailable: GitHubRelease?
    @Published var isUpToDate: Bool = false
    @Published var isChecking = false
    @Published var isDownloadingUpdate = false
    @Published var downloadErrorMessage: String?
    @Published var autoCheckUpdates: Bool {
        didSet { UserDefaults.standard.set(autoCheckUpdates, forKey: "autoCheckUpdates") }
    }

    private let owner = "leecode"
    private let repo = "soundbox"
    private let cooldownInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private var autoDismissTask: Task<Void, Never>?

    var lastUpdateCheck: Double {
        get { UserDefaults.standard.double(forKey: "lastUpdateCheck") }
        set { UserDefaults.standard.set(newValue, forKey: "lastUpdateCheck") }
    }

    var dismissedVersion: String {
        get { UserDefaults.standard.string(forKey: "dismissedVersion") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "dismissedVersion") }
    }

    init() {
        self.autoCheckUpdates = UserDefaults.standard.object(forKey: "autoCheckUpdates") as? Bool ?? true
    }

    func checkForUpdates(force: Bool = false) async {
        // Cooldown check (skip if checked < 24h ago, unless force)
        if !force {
            let elapsed = Date().timeIntervalSince1970 - lastUpdateCheck
            if elapsed < cooldownInterval { return }
        }

        isChecking = true
        autoDismissTask?.cancel()
        autoDismissTask = nil

        do {
            guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else {
                isChecking = false
                return
            }

            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                isChecking = false
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

            // Skip releases with no DMG
            guard release.dmgAsset != nil else {
                isChecking = false
                lastUpdateCheck = Date().timeIntervalSince1970
                return
            }

            lastUpdateCheck = Date().timeIntervalSince1970
            isChecking = false

            let currentVersion = Bundle.main.appVersion
            let remoteVersion = release.tagName
            let hasNewer = isNewerVersion(remoteVersion, than: currentVersion)

            if hasNewer {
                if force || dismissedVersion != remoteVersion {
                    updateAvailable = release
                    isUpToDate = false
                    downloadErrorMessage = nil
                }
            } else if force {
                isUpToDate = true
                scheduleAutoDismiss()
            }
        } catch {
            isChecking = false
        }
    }

    private func scheduleAutoDismiss() {
        autoDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.isUpToDate = false
            self.autoDismissTask = nil
        }
    }

    func dismiss() {
        if let release = updateAvailable {
            dismissedVersion = release.tagName
        }
        updateAvailable = nil
        downloadErrorMessage = nil
    }

    func dismissUpToDate() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        isUpToDate = false
    }

    func openReleasePage() {
        if let release = updateAvailable,
           let url = URL(string: release.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }

    func downloadAndOpenUpdate() async {
        guard !isDownloadingUpdate else { return }

        guard let asset = updateAvailable?.dmgAsset,
              let downloadURL = URL(string: asset.browserDownloadUrl) else {
            downloadErrorMessage = "未找到安装包"
            return
        }

        isDownloadingUpdate = true
        downloadErrorMessage = nil

        do {
            var request = URLRequest(url: downloadURL)
            request.timeoutInterval = 60

            let (temporaryURL, response) = try await URLSession.shared.download(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let destinationURL = downloadDestination(for: asset)
            let fileManager = FileManager.default

            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            isDownloadingUpdate = false
            if !NSWorkspace.shared.open(destinationURL) {
                downloadErrorMessage = "已下载，打开失败"
            }
        } catch {
            isDownloadingUpdate = false
            downloadErrorMessage = "下载失败，请重试"
        }
    }

    private func downloadDestination(for asset: GitHubAsset) -> URL {
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let safeFileName = asset.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return downloadsDirectory.appendingPathComponent(safeFileName)
    }
}
