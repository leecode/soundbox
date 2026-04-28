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
        assets.first { $0.name.hasSuffix(".dmg") }
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
    @Published var autoCheckUpdates: Bool {
        didSet { UserDefaults.standard.set(autoCheckUpdates, forKey: "autoCheckUpdates") }
    }

    private let owner = "leecode"
    private let repo = "soundbox"
    private let cooldownInterval: TimeInterval = 24 * 60 * 60 // 24 hours

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

            let currentVersion = Bundle.main.appVersion
            let remoteVersion = release.tagName
            let hasNewer = isNewerVersion(remoteVersion, than: currentVersion)

            if hasNewer {
                if force || dismissedVersion != remoteVersion {
                    updateAvailable = release
                    isUpToDate = false
                }
            } else if force {
                // Manual check, already on latest
                isUpToDate = true
                // Auto-dismiss after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                isUpToDate = false
            }

            lastUpdateCheck = Date().timeIntervalSince1970
        } catch {
            // Network error, rate limit, etc. — silent skip
        }

        isChecking = false
    }

    func dismiss() {
        if let release = updateAvailable {
            dismissedVersion = release.tagName
        }
        updateAvailable = nil
    }

    func openReleasePage() {
        if let release = updateAvailable,
           let url = URL(string: release.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}
