# Design System — SoundBox

## Product Context
- **What this is:** Native macOS audio player for DLsite voice works (音声作品), supporting Hi-Res playback, VTT subtitle sync, bookmarks, and script viewing.
- **Who it's for:** Voice work enthusiasts with local collections who need offline playback + subtitle sync.
- **Space/industry:** Niche audio player, no direct competitors. Nearest peers: Doppler, IINA, Vox (general music players).
- **Project type:** Desktop app (macOS native, SwiftUI)

## Aesthetic Direction
- **Direction:** Refined Minimal
- **Decoration level:** Intentional — cover art provides color and atmosphere, UI itself has minimal decoration. System materials (blur, vibrancy) provide depth.
- **Mood:** Quiet, content-forward. The interface stays out of the way. Cover art colors set the mood, subtitles carry the content, timeline provides control.
- **Key insight:** Unlike general music players where album art is the hero, SoundBox's visual anchor is the **timeline + subtitle content**. Most files have folder-level cover art (not embedded), so the cover serves as atmospheric background, not a standalone hero element.

## Typography
- **Display/Track Title:** System (.title2, semibold) — San Francisco on macOS. Not a cop-out: native apps should use native fonts.
- **Body/Artist:** System (.body) — same as above
- **Caption/Metadata:** System (.caption, .tertiary, .monospacedDigit) — for duration, file size, format info
- **Mono/Data:** SF Mono (.monospacedDigit) — for time displays (4:22 / 12:34)
- **Loading:** System fonts, no external loading needed
- **Scale (SwiftUI tokens):**
  - `.title2` (track names)
  - `.title3` (section headers)
  - `.body` (artist, general text)
  - `.subheadline` (tab labels, list items)
  - `.caption` (metadata, timestamps, format badges)
  - `.caption2` (tertiary info)

## Color
- **Approach:** Restrained — system semantic colors with one accent. Cover art provides ambient color.
- **Accent:** System accent (`.accentColor`, defaults to #007AFF blue)
  - Usage: active states, Hi-Res badge, play button, progress fill
- **Bookmark marker:** #FF9500 (orange)
  - Usage: bookmark markers on progress slider, bookmark icon, bookmark tags
- **Neutrals:** System semantic colors
  - `.primary` — main text (auto-adapts to light/dark)
  - `.secondary` — secondary text, descriptions
  - `.tertiary` — tertiary text, timestamps, hint text
- **Surfaces:** System materials
  - `.bar` — control bar background
  - `.regularMaterial` — cards, overlays, panels
  - `.ultraThinMaterial` — subtitle display overlay, floating elements
- **Dark mode:** Automatic via system semantic colors. All `.primary`/`.secondary`/`.tertiary` adapt. Cover blur background opacity reduced slightly in light mode (0.4 vs 0.6).
- **Semantic:** Error (#FF3B30), Warning (yellow system), Success (green system) — via `Color(nsColor:)` system colors.

## Spacing
- **Base unit:** 8px
- **Density:** Comfortable — not cramped, not wasteful. Audio players should feel relaxed.
- **Scale (used in SwiftUI padding/spacing):**
  - 2px: micro adjustments
  - 4px: tight internal spacing (icon-to-text, badge padding)
  - 8px: small gaps, search field margins
  - 12px: bookmark item spacing, subtitle line spacing
  - 16px: standard padding, list item padding
  - 20px: section gaps in main content
  - 24px: sidebar header padding
  - 30px: main content area padding
  - 32px: large section gaps

## Layout
- **Approach:** Grid-disciplined — three-column layout with fixed-size sidebar and side panel.
- **Column structure:**
  - Playlist sidebar: 280px fixed
  - Main content: flexible, fills remaining space
  - Side panel: 320px fixed, conditionally shown (⌘S toggle)
  - Control bar: 80px height, full width at bottom
- **Min window:** 900×680
- **Content area:** Cover art 200×200 (or placeholder), centered vertically with track info below, subtitle overlay near bottom.
- **Border radius:** System defaults
  - 4px: small elements, badges
  - 8px: buttons, search fields, cards
  - 12px: overlays, modals, cover art
  - Full circle: play button, volume handle

## Motion
- **Approach:** Minimal-functional — only transitions that aid comprehension.
- **Easing:** System default (ease-in-out)
- **Duration:** System default animation timing
- **Specific animations:**
  - Side panel: slide in/out with opacity fade (`.animation(.easeInOut)`)
  - Bookmark overlay: fade in with slight scale
  - Error toast: slide up from bottom, auto-dismiss after 3s
  - Progress handle: appear on hover via opacity transition
  - Cover art: cross-fade on track change
- **No animation:** Track list scrolling, subtitle text updates, playback state changes

## Components

### Cover Art Display
- Priority chain: embedded artwork data > external file (cover.jpg etc.) > placeholder (music.note.list SF Symbol)
- **Atmospheric background:** When cover art exists, extract dominant color and render as blurred background behind main content area. Opacity 0.6 (dark mode) / 0.4 (light mode). Blur radius 60px.
- **Thumbnail:** 200×200 in main content, 36×36 in control bar. Rounded corners (8px).

### Progress Slider
- Height: 4px default, 6px on hover
- Track: surface color, fill: accent color
- Handle: 12px circle, white, appears on hover
- Bookmark markers: 2px wide, 10px tall, orange (#FF9500), positioned at bookmark timestamps
- Click anywhere on track to seek. Click bookmark marker to seek to bookmark.

### Side Panel Tabs
- **Current:** Text labels (字幕 | 台本 | 书签)
- **Proposed:** SF Symbol icons (text.bubble | doc.text | bookmark) — more compact, visually cleaner
- Active state: accent color + bottom border
- Tab switching preserves scroll position per tab

### Bookmark Overlay
- Centered modal with dimmed background (black 0.2 opacity)
- Shows timestamp, text field for label, Save/Cancel buttons
- Auto-focuses text field on appear
- Dismiss: Enter to save, Escape to cancel, click outside to cancel

### Empty States
All empty states follow this pattern:
1. SF Symbol icon (large, tertiary color)
2. Title text (body weight)
3. Instruction text (caption, tertiary)
4. Optional: primary action button

### Error Toast
- Yellow warning icon + error text
- Material background, rounded corners, shadow
- Auto-dismiss after 3 seconds
- Positioned above control bar

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-18 | Initial design system created | Created by /design-consultation. Refined Minimal direction chosen for macOS native feel with voice-work-specific adaptations. |
| 2026-04-18 | Cover art as atmospheric background | DLsite voice works have folder-level cover art, not embedded. Using it as blurred background leverages existing assets without requiring metadata. |
| 2026-04-18 | Timeline as visual hero | Voice work users navigate by timestamp and bookmark more than general music listeners. Progress slider deserves more visual weight. |
| 2026-04-18 | System fonts only | macOS native app. Non-system fonts feel foreign on macOS. San Francisco is excellent. |
| 2026-04-18 | Bookmark orange (#FF9500) | Distinct from blue accent. High visibility on both light and dark progress bar. Matches macOS system orange. |
