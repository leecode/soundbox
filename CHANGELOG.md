# Changelog

All notable changes to SoundBox will be documented in this file.

## [0.1.2-beta] - 2026-05-02

### Added

- Local web companion for controlling SoundBox from a phone browser on the same Wi-Fi.
- Companion controls for playback, track navigation, seeking, speed changes, subtitle jumps, and bookmarks.
- Token-protected companion API endpoints for local network access.
- SoundBox unit test target and shared scheme coverage for companion server authentication and command dispatch.

### Fixed

- Shift-JIS script fallback now uses the correct NSString encoding conversion.

## [0.1.1-beta] - 2026-05-02

### Added

- A-B repeat controls with manual loop points.
- Current subtitle cue looping for subtitle-driven listening.
- Grouped subtitle preview navigation with follow-current-cue behavior.
- Floating subtitle appearance fallback that applies the selected app theme through AppKit.

### Changed

- Updated the English README to document A-B repeat, floating subtitles, and subtitle preview follow mode.

## [0.1.0-beta] - 2026-05-02

### Added

- Native macOS audio playback built with SwiftUI and AVAudioEngine.
- Local folder import for voice work and ASMR collections.
- Playlist browsing with duplicate prevention and track ordering.
- Support for common audio formats including WAV, FLAC, AIFF, ALAC, M4A, AAC, MP3, and OGG.
- Hi-Res audio metadata display for 96 kHz or 24-bit files and above.
- VTT subtitle parsing, real-time subtitle sync, and a subtitle preview panel.
- Matching `.txt` script loading for voice work tracks.
- Folder artwork and embedded audio metadata display.
- Playback controls for play, pause, previous/next track, seeking, repeat modes, volume, mute, and playback speed.
- Bookmarks for saving and revisiting timestamps.
- Sleep timer with fade-out near the end.
- Floating subtitle panel and macOS media key support.
- Recent folder history for quickly reopening local collections.
- GitHub release update checks with direct DMG downloads.
- English and Simplified Chinese README files.

### Known Limitations

- The beta DMG is not signed with an Apple Developer ID certificate or notarized by Apple.
- macOS Gatekeeper may block the app on first launch. Users may need to open it manually from System Settings or use `Open` from Finder's context menu.

### Notes

- This release is intended as an early public beta for testing local playback, subtitles, playlists, and voice work workflows.
