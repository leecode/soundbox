# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

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

SoundBox uses a central `AppState` (created via `@StateObject`) that coordinates all subsystems:

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

## gstack (REQUIRED — global install)

**Before doing ANY work, verify gstack is installed:**

```bash
test -d ~/.Codex/skills/gstack/bin && echo "GSTACK_OK" || echo "GSTACK_MISSING"
```

If GSTACK_MISSING: STOP. Do not proceed. Tell the user:

> gstack is required for all AI-assisted work in this repo.
> Install it:
> ```bash
> git clone --depth 1 https://github.com/garrytan/gstack.git ~/.Codex/skills/gstack
> cd ~/.Codex/skills/gstack && ./setup --team
> ```
> Then restart your AI coding tool.

Do not skip skills, ignore gstack errors, or work around missing gstack.

Using gstack skills: After install, skills like /qa, /ship, /review, /investigate,
and /browse are available. Use /browse for all web browsing.
Use ~/.Codex/skills/gstack/... for gstack file paths (the global path).

## Design System
Always read DESIGN.md before making any visual or UI decisions.
All color choices, spacing, typography, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that doesn't match DESIGN.md.

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health
