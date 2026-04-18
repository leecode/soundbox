# SoundBox UI Visual QA Checklist

Date: 2026-04-18
Basis: DESIGN.md + current SwiftUI implementation

## Scope
- Layout geometry
- Typography hierarchy
- Color/material consistency
- Interaction feedback (hover/active)
- Empty states
- Responsive behavior for 900 / 1200 / 1600 widths

## 900px Width
- [x] 3-column shell preserved with fixed sidebar/panel widths and 80px control bar
- [x] Main hero auto-switches to compact vertical layout (`compactHeroThreshold`)
- [x] Bottom-right controls degrade gracefully via `ViewThatFits` (hide speed label + shorter volume)
- [x] Progress slider remains usable (drag, hover tooltip, bookmark taps)
- [x] Empty states remain centered and readable

## 1200px Width
- [x] Hero uses horizontal layout (200x200 cover + metadata)
- [x] Subtitle panel and playlist both maintain comfortable spacing
- [x] Timeline remains primary visual anchor with clear timestamps/bookmarks
- [x] Hover states visible in playlist rows and subtitle rows

## 1600px Width
- [x] Content remains centered and not over-stretched
- [x] Main area atmosphere (blur + material) still balanced
- [x] Typography hierarchy remains stable (title/body/caption)

## Design System Conformance
- [x] Fixed widths: sidebar 280, side panel 320
- [x] Control bar height: 80
- [x] Cover size: 200x200
- [x] Progress slider: 4px default / 6px hover
- [x] Bookmark markers: 2x10, orange `#FF9500`
- [x] Radius system aligned to 8/12 where intended
- [x] Semantic material surfaces used (`.bar`, `.regularMaterial`, `.ultraThinMaterial`)

## Interaction QA
- [x] Side panel toggle animation (move + fade)
- [x] Slider hover line + time bubble
- [x] Slider handle appears on hover/drag
- [x] Playlist row hover + playing state highlight
- [x] Subtitle row hover + active state highlight
- [x] Bookmark overlay dim background and dismissal behavior preserved

## Empty State QA
- [x] Main empty state follows icon/title/description/action pattern
- [x] Playlist empty state includes primary action
- [x] Script and subtitle empty states are visually consistent with panel context
- [x] Bookmark empty state uses same semantic pattern

## Notes / Residual Checks (Manual in Xcode Preview/App)
- [ ] Verify exact perceived blur strength in light mode vs dark mode on real cover art assets
- [ ] Verify long CJK title wrapping for 2+ line cases in compact hero mode
- [ ] Verify very dense bookmark sets (>30) do not create visual clutter on slider

## Conclusion
Current UI is ready for visual sign-off pending the three manual checks above.
