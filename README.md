# SoundBox

English | [Simplified Chinese](README.zh-CN.md)

SoundBox is a native macOS audio player designed for DLsite voice works, ASMR, and voice dramas. It focuses on local playback, VTT subtitle support, playlist management, bookmarks, media keys, and Hi-Res audio-friendly workflows.

## Features

- **Native macOS app** - Built with SwiftUI and AVAudioEngine.
- **Local-first playback** - Play your local voice work collections without relying on online players.
- **Broad audio format support** - Supports WAV, FLAC, AIFF, ALAC, MP3, AAC, OGG, and other common formats available through the macOS audio stack.
- **Hi-Res audio display** - Detects high-resolution files at 96 kHz or 24-bit and above.
- **VTT subtitles** - Automatically finds matching `.vtt` files, syncs subtitles during playback, and provides a subtitle preview panel.
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
5. Add bookmarks with `Cmd+B` while listening.

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
├── Models/
│   ├── Models.swift               # Audio, track, playlist, playback models
│   └── Bookmark.swift             # Bookmark model
├── Views/
│   ├── ContentView.swift          # Main app layout
│   ├── PlaylistView.swift         # Playlist sidebar
│   ├── PlayerControlBar.swift     # Playback controls
│   ├── SubtitleView.swift         # Current subtitle display
│   └── SubtitlePreviewPanel.swift # Subtitle browser
├── AudioEngine/
│   └── AudioEngine.swift          # AVAudioEngine playback wrapper
├── Decoder/
│   └── LosslessDecoder.swift      # Audio metadata and format reader
├── Subtitle/
│   └── VTTParser.swift            # VTT parser and subtitle managers
├── Floating/
│   └── FloatingSubtitlePanel.swift
├── Managers/
│   └── BookmarkManager.swift
├── Update/
│   └── UpdateManager.swift
└── Utils/
    ├── FileScanner.swift          # Folder scanner and sidecar file matching
    ├── FormatUtils.swift
    └── ImageCache.swift
```

## Architecture

SoundBox uses a central `AppState` object to coordinate playback, playlists, subtitles, bookmarks, folder history, sleep timer state, and update checks.

`AudioEngine` is a singleton wrapper around `AVAudioEngine` and `AVAudioPlayerNode`. It reports playback state and progress through a delegate, while `AppState` bridges those updates into SwiftUI-friendly observable state.

Subtitle handling is split between real-time sync and preview preloading:

- `SubtitleManager` updates the current subtitle during playback.
- `SubtitlePreviewManager` preloads cues for the whole playlist so users can browse subtitles across tracks.

## Roadmap

- [x] Basic local playback
- [x] VTT subtitle sync
- [x] Subtitle preview panel
- [x] Playlist and folder import
- [x] Folder history
- [x] Repeat modes
- [x] Playback speed
- [x] Sleep timer
- [x] Bookmarks
- [x] Media key support
- [x] Artwork and metadata display

## License

MIT License
