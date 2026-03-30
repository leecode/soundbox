# 媒体键支持 & 封面显示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add keyboard media key support (play/pause/prev/next) and folder-based cover art display to SoundBox.

**Architecture:** Cover art is found during FileScanner's existing async scan, attached to `AudioFile` as a URL, and rendered conditionally in `CurrentTrackView`. Media keys use `MPRemoteCommandCenter` wired into `AppState`'s existing playback methods, with `MPNowPlayingInfoCenter` updated on track/state changes.

**Tech Stack:** Swift, SwiftUI, MediaPlayer framework (MPRemoteCommandCenter), AVFoundation

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `SoundBox/Models/Models.swift` | Add `artworkURL` to `AudioFile` |
| Modify | `SoundBox/Utils/FileScanner.swift` | Add cover art search in scan flow |
| Modify | `SoundBox/Views/ContentView.swift` | Conditional cover art in `CurrentTrackView` |
| Modify | `SoundBox/App/SoundBoxApp.swift` | Add media key setup in `AppState` |

---

## Part 1: Cover Art Display

### Task 1: Add `artworkURL` to `AudioFile`

**Files:**
- Modify: `SoundBox/Models/Models.swift:27-64`

- [ ] **Step 1: Add `artworkURL` property and update init**

In `SoundBox/Models/Models.swift`, add `artworkURL: URL?` to `AudioFile`:

```swift
struct AudioFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let format: AudioFormat
    let duration: TimeInterval
    let fileSize: UInt64
    let subtitleURL: URL?
    let artworkURL: URL?

    init(url: URL, format: AudioFormat = .cdQuality, duration: TimeInterval = 0, subtitleURL: URL? = nil, artworkURL: URL? = nil) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.format = format
        self.duration = duration
        self.fileSize = UInt64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        self.subtitleURL = subtitleURL
        self.artworkURL = artworkURL
    }
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project SoundBox.xcodeproj -scheme SoundBox build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add SoundBox/Models/Models.swift
git commit -m "feat: add artworkURL property to AudioFile model"
```

---

### Task 2: Add cover art search to FileScanner

**Files:**
- Modify: `SoundBox/Utils/FileScanner.swift:1-162`

- [ ] **Step 1: Add `findArtworkFile` method and integrate into scan**

In `SoundBox/Utils/FileScanner.swift`, add a new method after `findSubtitleFile`:

```swift
// MARK: - Find Artwork File
private func findArtworkFile(in directory: URL) -> URL? {
    let artworkNames = ["cover", "folder", "album"]
    let artworkExtensions = ["jpg", "jpeg", "png", "webp"]

    let files = (try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: .skipsHiddenFiles
    )) ?? []

    for name in artworkNames {
        for ext in artworkExtensions {
            if let match = files.first(where: {
                $0.deletingPathExtension().lastPathComponent.lowercased() == name &&
                $0.pathExtension.lowercased() == ext
            }) {
                return match
            }
        }
    }
    return nil
}
```

Then in `scanDirectory`, after the `audioFiles.sort(...)` block and before the `let group = DispatchGroup()` line, add artwork lookup:

```swift
let artworkURL = self.findArtworkFile(in: url)
```

Then in `createTrack`, pass the artwork URL through. Update the `createTrack` method signature and call site.

First, update the call site in the `for` loop:

```swift
for (audioURL, subtitleURL) in audioFiles {
    group.enter()
    let currentIndex = index
    index += 1
    self.createTrack(from: audioURL, subtitleURL: subtitleURL, artworkURL: artworkURL, index: currentIndex) { track in
        syncQueue.sync {
            if let track = track {
                tracks.append(track)
            }
        }
        group.leave()
    }
}
```

Then update the `createTrack` method signature and body:

```swift
private func createTrack(from url: URL, subtitleURL: URL?, artworkURL: URL?, index: Int, completion: @escaping (Track?) -> Void) {
    let decoder = LosslessDecoder()
    decoder.getAudioInfo(url) { result in
        switch result {
        case .success(let info):
            let audioFile = AudioFile(
                url: url,
                format: info.audioFormat,
                duration: info.duration,
                subtitleURL: subtitleURL,
                artworkURL: artworkURL
            )

            let track = Track(
                audioFile: audioFile,
                index: index,
                title: url.deletingPathExtension().lastPathComponent
            )
            completion(track)

        case .failure:
            completion(nil)
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project SoundBox.xcodeproj -scheme SoundBox build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add SoundBox/Utils/FileScanner.swift
git commit -m "feat: scan for cover art files (cover/folder/album.*) during folder scan"
```

---

### Task 3: Render cover art in CurrentTrackView

**Files:**
- Modify: `SoundBox/Views/ContentView.swift:78-135`

- [ ] **Step 1: Replace waveform placeholder with conditional cover art**

In `SoundBox/Views/ContentView.swift`, replace the `CurrentTrackView` body (the `RoundedRectangle` block at lines 85-98):

```swift
struct CurrentTrackView: View {
    let track: Track

    var body: some View {
        VStack(spacing: 12) {
            // 封面图或波形占位
            Group {
                if let artworkURL = track.audioFile.artworkURL,
                   let nsImage = NSImage(contentsOf: artworkURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
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
            .frame(width: 200, height: 200)
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project SoundBox.xcodeproj -scheme SoundBox build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Manual test — open a folder with a cover.jpg and verify the image appears in the main view center; open a folder without cover art and verify the waveform icon still shows**

- [ ] **Step 4: Commit**

```bash
git add SoundBox/Views/ContentView.swift
git commit -m "feat: display cover art in main view when available"
```

---

## Part 2: Media Key Support

### Task 4: Add MediaPlayer import and setup media key handlers in AppState

**Files:**
- Modify: `SoundBox/App/SoundBoxApp.swift:1-359`

- [ ] **Step 1: Add `import MediaPlayer` at the top of the file**

Add at line 1:

```swift
import MediaPlayer
```

- [ ] **Step 2: Add media key handler properties and setup method to AppState**

Add these properties and methods inside `AppState` (after `private let fileScanner = FileScanner()`):

```swift
// MARK: - Media Key Support
private var commandCenter: MPRemoteCommandCenter?

private func setupMediaKeys() {
    let commandCenter = MPRemoteCommandCenter.shared()
    self.commandCenter = commandCenter

    commandCenter.playCommand.addTarget { [weak self] _ in
        guard let self = self else { return .commandFailed }
        DispatchQueue.main.async {
            if self.playerState.playbackState == .paused {
                AudioEngine.shared.resume()
            } else if let track = self.playlist.currentTrack {
                AudioEngine.shared.loadAndPlay(track.audioFile.url)
            }
        }
        return .success
    }

    commandCenter.pauseCommand.addTarget { [weak self] _ in
        guard let self = self else { return .commandFailed }
        DispatchQueue.main.async {
            if self.playerState.playbackState.isPlaying {
                AudioEngine.shared.pause()
            }
        }
        return .success
    }

    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
        guard let self = self else { return .commandFailed }
        DispatchQueue.main.async {
            self.playNextTrackMediaKey()
        }
        return .success
    }

    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
        guard let self = self else { return .commandFailed }
        DispatchQueue.main.async {
            self.playPreviousTrackMediaKey()
        }
        return .success
    }
}

private func playNextTrackMediaKey() {
    guard !playlist.tracks.isEmpty else { return }
    let newIndex: Int
    if playlist.currentIndex < playlist.tracks.count - 1 {
        newIndex = playlist.currentIndex + 1
    } else if playlist.repeatMode == .all {
        newIndex = 0
    } else {
        return
    }
    playlist.selectTrack(at: newIndex)
    if let track = playlist.currentTrack {
        AudioEngine.shared.loadAndPlay(track.audioFile.url)
    }
}

private func playPreviousTrackMediaKey() {
    guard !playlist.tracks.isEmpty else { return }
    let newIndex: Int
    if playlist.currentIndex > 0 {
        newIndex = playlist.currentIndex - 1
    } else if playlist.repeatMode == .all {
        newIndex = playlist.tracks.count - 1
    } else {
        return
    }
    playlist.selectTrack(at: newIndex)
    if let track = playlist.currentTrack {
        AudioEngine.shared.loadAndPlay(track.audioFile.url)
    }
}
```

- [ ] **Step 3: Call `setupMediaKeys()` in `AppState.init()`**

In the `init()` method, add after `AudioEngine.shared.delegate = self`:

```swift
// 初始化媒体键
setupMediaKeys()
```

- [ ] **Step 4: Add `updateNowPlayingInfo()` and call it on track/state changes**

Add the method inside `AppState`:

```swift
private func updateNowPlayingInfo() {
    var info: [String: Any] = [:]
    if let track = playlist.currentTrack {
        info[MPMediaItemPropertyTitle] = track.title
    }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info.isEmpty ? nil : info
}
```

Call `updateNowPlayingInfo()` in two places:

1. In `audioEngine(_:didChangeState:)`, at the top of the `DispatchQueue.main.async` block (after `self.playerState.playbackState = state`):

```swift
self.updateNowPlayingInfo()
```

2. In `scanAndAddFolder`, after `self?.playlist.addTracks(tracks)`:

```swift
self?.updateNowPlayingInfo()
```

- [ ] **Step 5: Build to verify compilation**

Run: `xcodebuild -project SoundBox.xcodeproj -scheme SoundBox build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Manual test — play a track, press keyboard media keys (F7/F8/F9 on Touch Bar or Fn keyboard), verify play/pause/prev/next respond correctly**

- [ ] **Step 7: Commit**

```bash
git add SoundBox/App/SoundBoxApp.swift
git commit -m "feat: add keyboard media key support via MPRemoteCommandCenter"
```

---

### Task 5: Update README roadmap

**Files:**
- Modify: `README.md:91-92`

- [ ] **Step 1: Update the roadmap checkboxes**

```markdown
- [x] 媒体键支持（播放/暂停/上下曲）
- [x] 封面显示
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update roadmap - media keys and cover art completed"
```
