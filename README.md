# SoundBox

English | [Simplified Chinese](README.zh-CN.md)

SoundBox is a native macOS audio player designed for DLsite voice works, ASMR, and voice dramas. It focuses on local playback, VTT subtitle support, playlist management, bookmarks, media keys, and Hi-Res audio-friendly workflows.

## Features

- **Native macOS app** - Built with SwiftUI and AVAudioEngine.
- **Local-first playback** - Play your local voice work collections without relying on online players.
- **Phone companion** - Start a token-protected local web companion and control playback from a phone browser on the same Wi-Fi.
- **Broad audio format support** - Supports WAV, FLAC, AIFF, ALAC, MP3, AAC, OGG, and other common formats available through the macOS audio stack.
- **Hi-Res audio display** - Detects high-resolution files at 96 kHz or 24-bit and above.
- **VTT subtitles** - Automatically finds matching `.vtt` files, syncs subtitles during playback, provides grouped subtitle previews, and can follow the currently playing cue.
- **Subtitle navigation** - Browse cues by track and jump directly to a subtitle timestamp.
- **Floating subtitles** - Show the current subtitle in a separate floating panel with remembered window position.
- **A-B loop** - Set A and B points manually or loop the current subtitle cue.
- **Script support** - Loads matching `.txt` scripts for voice works when available.
- **Playlist management** - Import folders, browse tracks, prevent duplicates, and keep track order tidy.
- **Folder history** - Quickly reopen recently used local collections.
- **Playback controls** - Play, pause, previous/next track, seek, repeat modes, volume, mute, and playback speed.
- **Bookmarks** - Mark important timestamps and jump back to them later.
- **Sleep timer** - Stop playback after a selected duration, with a short fade-out near the end.
- **Media keys** - Control playback with macOS keyboard media keys.
- **Artwork and metadata** - Loads folder artwork and embedded track metadata when available.
- **Update checks** - Can check GitHub releases for newer DMG builds.

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later

## Build

Open the project in Xcode:

```bash
open SoundBox.xcodeproj
```

Build and run from Xcode with `Cmd+R`.

You can also build from the command line:

```bash
xcodebuild -project SoundBox.xcodeproj -scheme SoundBox build
```

## Usage

1. Choose `File` -> `Open Folder...` (`Cmd+O`) and select a folder that contains audio files.
2. Pick a track from the playlist.
3. Use the bottom control bar to play, pause, seek, change volume, switch repeat mode, or change playback speed.
4. Open the subtitle preview panel with `Cmd+S` when VTT subtitles are available.
5. Jump to subtitle lines from the preview panel, or enable follow mode to keep the current cue in view.
6. Use the playback menu to set A-B loops or loop the current subtitle cue.
7. Open floating subtitles with `Shift+Cmd+F`.
8. Add bookmarks with `Cmd+B` while listening.
9. Click the phone button in the bottom control bar, start the companion server, and open the generated URL on a phone connected to the same Wi-Fi.

## Keyboard Shortcuts

- `Cmd+O` - Open folders
- `Space` - Play or pause
- `Left Arrow` / `Right Arrow` - Seek backward or forward 5 seconds
- `Cmd+Left Arrow` / `Cmd+Right Arrow` - Previous or next track
- `Cmd+S` - Toggle subtitle preview
- `Cmd+B` - Add bookmark
- `Cmd+R` - Cycle repeat mode
- `Shift+Cmd+F` - Toggle floating subtitles

## Project Structure

```text
SoundBox/
├── App/
│   └── SoundBoxApp.swift          # App entry, menus, AppState coordinator
├── AudioEngine/
│   └── AudioEngine.swift          # AVAudioEngine playback wrapper
├── Companion/
│   ├── CompanionMessages.swift    # Codable state and command payloads
│   └── CompanionWebServer.swift   # Local web companion server and phone UI
├── Decoder/
│   └── LosslessDecoder.swift      # Audio metadata and format reader
├── Floating/
│   ├── FloatingSubtitlePanel.swift # Floating subtitle window
│   └── FloatingSubtitleView.swift  # Floating subtitle view
├── Managers/
│   └── BookmarkManager.swift      # Bookmark persistence and lookup
├── Models/
│   ├── Models.swift               # Audio, track, playlist, playback models
│   └── Bookmark.swift             # Bookmark model
├── Subtitle/
│   └── VTTParser.swift            # VTT parser and subtitle managers
├── Update/
│   └── UpdateManager.swift        # GitHub release update checks
├── Utils/
│   ├── FileScanner.swift          # Folder scanner and sidecar file matching
│   ├── FormatUtils.swift
│   └── ImageCache.swift
├── Views/
│   ├── ContentView.swift          # Main app layout
│   ├── CompanionControlView.swift # Companion server popover
│   ├── PlaylistView.swift         # Playlist sidebar
│   ├── PlayerControlBar.swift     # Playback controls
│   ├── SubtitleView.swift         # Current subtitle display
│   └── SubtitlePreviewPanel.swift # Subtitle browser
└── Resources/
    └── Info.plist                 # App configuration
```

## Architecture

SoundBox uses a central `AppState` object to coordinate playback, playlists, subtitles, bookmarks, folder history, sleep timer state, and update checks.

`AudioEngine` is a singleton wrapper around `AVAudioEngine` and `AVAudioPlayerNode`. It reports playback state and progress through a delegate, while `AppState` bridges those updates into SwiftUI-friendly observable state.

Subtitle handling is split between real-time sync and preview preloading:

- `SubtitleManager` updates the current subtitle during playback.
- `SubtitlePreviewManager` preloads cues for the whole playlist so users can browse subtitles across tracks.

The phone companion runs as a local HTTP server from the Mac app. It serves a small mobile web UI and token-protected JSON endpoints for playback state and commands. Audio continues to play on the Mac; the phone acts as a remote control and subtitle display.

## Roadmap

- [x] Basic local playback
- [x] VTT subtitle sync
- [x] Grouped subtitle preview and follow mode
- [x] Floating subtitle panel
- [x] Playlist and folder import
- [x] Folder history
- [x] Repeat modes
- [x] A-B loop and current subtitle cue loop
- [x] Playback speed
- [x] Sleep timer
- [x] Bookmarks
- [x] Media key support
- [x] Artwork and metadata display
- [x] Local phone companion web app

## License

MIT License
