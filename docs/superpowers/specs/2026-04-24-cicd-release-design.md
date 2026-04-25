# CI/CD Release Pipeline Design

## Overview

Set up GitHub Actions CI/CD to automatically build a macOS DMG installer and publish it as a GitHub Release when a version tag is pushed.

## Requirements

- **Trigger**: Push tag matching `v*` (e.g., `v1.0.0`)
- **Runner**: GitHub-hosted `macos-14`
- **Artifact**: `SoundBox-{version}.dmg` (e.g., `SoundBox-1.0.0.dmg`)
- **Distribution**: Direct download from GitHub Releases (no App Store, no notarization)
- **Signing**: Ad-hoc code signing only (no Apple Developer certificate)

## Workflow Steps

1. **Checkout** — clone repository at tag ref
2. **Extract version** — strip `v` prefix from tag name (e.g., `v1.0.0` → `1.0.0`)
3. **Build archive** — `xcodebuild archive` with Release configuration
4. **Export app** — `xcodebuild -exportArchive` to produce `.app` bundle (no signing identity, ad-hoc)
5. **Create DMG** — assemble `.app` + `/Applications` symlink, package with `hdiutil`
6. **Create release** — `gh release create` with auto-generated notes and DMG asset

## File Changes

| File | Action |
|------|--------|
| `.github/workflows/release.yml` | New — GitHub Actions workflow |
| `ExportOptions.plist` | New — Xcode export options (no signing) |

No changes to existing source files.

## ExportOptions.plist

Uses `signingStyle` = `automatic` with no team ID, resulting in ad-hoc signed app. This avoids requiring any Apple Developer credentials as CI secrets.

## DMG Structure

```
SoundBox-1.0.0.dmg
├── SoundBox.app
└── Applications (symlink → /Applications)
```

Users mount the DMG, drag SoundBox.app to Applications, done.

## User Experience Caveat

Without Apple Developer signing and notarization, macOS Gatekeeper will show a warning on first launch. Users bypass by right-clicking the app and selecting "Open", or running `xattr -cr SoundBox.app`. This is standard for unsigned macOS app distribution.

## Local Verification

The entire pipeline can be simulated locally:

```bash
# Build
xcodebuild archive \
  -project SoundBox.xcodeproj -scheme SoundBox \
  -configuration Release \
  -archivePath build/SoundBox.xcarchive

# Export
xcodebuild -exportArchive \
  -archivePath build/SoundBox.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist

# Create DMG
mkdir -p build/dmg_temp
cp -R build/export/SoundBox.app build/dmg_temp/
ln -s /Applications build/dmg_temp/Applications
hdiutil create -volname "SoundBox" \
  build/SoundBox-1.0.0.dmg \
  -srcfolder build/dmg_temp
```

## Future Enhancements (Not in scope)

- Apple Developer signing + notarization (requires paid Apple Developer account and CI secrets setup)
- Sparkle auto-update framework integration
- Custom DMG background image
- PR CI checks (build verification on push to branches)
