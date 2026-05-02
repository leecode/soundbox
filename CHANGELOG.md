# Changelog

All notable changes to SoundBox will be documented in this file.

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
