# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run

SoundBox is a native macOS SwiftUI application built with Xcode.

```bash
# Open project in Xcode
open SoundBox.xcodeproj

# Build from command line
xcodebuild -project SoundBox.xcodeproj -scheme SoundBox build

# Run from Xcode: ⌘R
```

**Important**: This is a native Swift project - always build and test through Xcode, not command line tools.

## Architecture Overview

SoundBox uses a singleton-based architecture with a central `AppState` that coordinates all subsystems:

```
SoundBoxApp (App Entry)
    ↓
AppState (Central Coordinator)
    ├── AudioEngine (Singleton - AVAudioEngine wrapper)
    ├── Playlist (Track management)
    ├── SubtitleManager (VTT parsing/display)
    ├── SubtitlePreviewManager (Preloads all subtitles)
    ├── FolderHistoryManager (Recent folders)
    └── PlayerState (Observable playback state)
```

### Key Subsystems

**AudioEngine** (`AudioEngine/AudioEngine.swift`)
- Singleton wrapping `AVAudioEngine` and `AVAudioPlayerNode`
- Uses delegate pattern (`AudioEngineDelegate`) for state/progress updates
- Implements playback token system to handle seek operations correctly
- Progress timer runs at 0.25s intervals (CPU optimization)

**AppState** (`App/SoundBoxApp.swift`)
- Central `ObservableObject` coordinating all managers
- Propagates state changes via Combine `sink` subscriptions
- Handles auto-advance on track completion (respecting repeat modes)
- Bridges AudioEngine callbacks to SwiftUI updates

**Models** (`Models/Models.swift`)
- `AudioFile`: Represents audio file with format metadata
- `Track`: Wrapper around AudioFile with metadata
- `Playlist`: Manages track list, current index, repeat modes
- `PlayerState`: High-frequency playback state (time, volume, subtitle)
- `PlaybackState`: Enum for player states (stopped/playing/paused/finished/error)

**Subtitle System** (`Subtitle/VTTParser.swift`)
- `VTTParser`: Static parser for VTT format
- `SubtitleManager`: Real-time subtitle sync during playback
- `SubtitlePreviewManager`: Background preloading of all subtitles

### View Structure

Views are organized by function and observe state via `@EnvironmentObject` or `@ObservedObject`:

- `ContentView`: Main layout (sidebar + main content + control bar)
- `PlaylistView`: Sidebar track list
- `PlayerControlBar`: Bottom controls with custom progress slider
- `SubtitleView`: Current subtitle display
- `SubtitlePreviewPanel`: Collapsible subtitle browser

## Important Patterns

**Delegate Pattern**: AudioEngine communicates via delegate, not Combine. This is intentional - delegate callbacks happen on background threads and must dispatch to main thread before updating `@Published` properties.

**Playback Token**: When seeking, a new token invalidates previous completion handlers. This prevents stale callbacks from triggering "track finished" state after a seek.

**State Propagation**: AppState manually propagates changes from child ObservableObjects (Playlist, SubtitleManager, etc.) via Combine `sink`. This avoids views needing to observe multiple objects directly.

**Progress Timer**: Updates at 0.25s intervals, not per frame. This reduces CPU usage for the subtitle preview panel.

**AudioFile Hashable**: AudioFile conforms to `Hashable` by URL only - this enables duplicate detection in playlists.

## File Scanning

File scanning happens asynchronously via `FileScanner` (`Utils/FileScanner.swift`). It:
- Scans directories for audio files
- Automatically finds matching `.vtt` subtitle files
- Callbacks on main thread with Track array

## Repeat Modes

Playlist supports three repeat modes:
- `.none`: Stop after last track
- `.one`: Loop current track
- `.all`: Loop entire playlist

Auto-advance logic is in `AppState.playNextTrack()` - must handle all three modes.

## Development Notes

- Project uses Swift 5.9+ features (if/let shorthand, etc.)
- All UI is SwiftUI - no AppKit/UIKit except for `NSOpenPanel`
- Chinese UI strings throughout
- Hi-Res audio detection via `AudioFormat.isHiRes` (≥96kHz or ≥24-bit)
