# CI/CD Release Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set up GitHub Actions to build a macOS DMG and publish a GitHub Release on tag push.

**Architecture:** Single workflow file triggered by `v*` tag pushes. Uses `xcodebuild` for building, `hdiutil` for DMG creation, and `gh` CLI for release publishing. Ad-hoc signing only — no Apple Developer credentials needed.

**Tech Stack:** GitHub Actions, xcodebuild, hdiutil, GitHub CLI

---

### Task 1: Create ExportOptions.plist

**Files:**
- Create: `ExportOptions.plist`

- [ ] **Step 1: Create the export options file**

This file tells `xcodebuild -exportArchive` how to export the app. We use `automatic` signing with no team ID, which produces an ad-hoc signed app.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>copy</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

Note: `method` is set to `copy` (not `app-store` or `developer-id`) because we are not distributing through the App Store or using Developer ID signing. The `copy` method simply exports the app bundle as-is.

- [ ] **Step 2: Verify the file is valid XML**

Run: `plutil -lint ExportOptions.plist`
Expected: `ExportOptions.plist: OK`

- [ ] **Step 3: Commit**

```bash
git add ExportOptions.plist
git commit -m "feat: add ExportOptions.plist for CI export"
```

---

### Task 2: Create GitHub Actions release workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Create the workflow directory**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 2: Create the release workflow file**

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: macos-14
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF_NAME#v}" >> $GITHUB_OUTPUT

      - name: Build archive
        run: |
          xcodebuild archive \
            -project SoundBox.xcodeproj \
            -scheme SoundBox \
            -configuration Release \
            -archivePath build/SoundBox.xcarchive \
            MARKETING_VERSION=${{ steps.version.outputs.VERSION }} \
            CURRENT_PROJECT_VERSION=1

      - name: Export app
        run: |
          xcodebuild -exportArchive \
            -archivePath build/SoundBox.xcarchive \
            -exportPath build/export \
            -exportOptionsPlist ExportOptions.plist

      - name: Create DMG
        run: |
          mkdir -p build/dmg_temp
          cp -R build/export/SoundBox.app build/dmg_temp/
          ln -s /Applications build/dmg_temp/Applications
          hdiutil create \
            -volname "SoundBox" \
            -srcfolder build/dmg_temp \
            -ov \
            -format UDZO \
            "build/SoundBox-${{ steps.version.outputs.VERSION }}.dmg"

      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release create "${GITHUB_REF_NAME}" \
            "build/SoundBox-${{ steps.version.outputs.VERSION }}.dmg" \
            --title "SoundBox ${{ steps.version.outputs.VERSION }}" \
            --generate-notes
```

Key details:
- `macos-14` runner provides Xcode 15 with macOS 14 SDK
- `MARKETING_VERSION` overrides the app version from the tag
- `GITHUB_TOKEN` is automatically provided by GitHub Actions — no secrets to configure
- `--generate-notes` auto-generates release notes from commits since the last tag
- `-format UDZO` creates a compressed DMG

- [ ] **Step 3: Validate YAML syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"`
Expected: no output (success)

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "feat: add GitHub Actions release workflow"
```

---

### Task 3: Verify workflow locally with act (optional)

**Files:** None (verification only)

- [ ] **Step 1: Check if `act` is installed**

Run: `which act`

If not installed, skip this task — the workflow will be verified on the first real tag push.

- [ ] **Step 2: Dry-run the workflow**

Run: `act -n push -e '.github/workflows/release.yml'`
Expected: dry-run completes without errors (may show missing image warnings, which is fine for macOS runners)

---

### Task 4: Test with a real tag push

**Files:** None (end-to-end verification)

- [ ] **Step 1: Create and push a test tag**

```bash
git tag v0.1.0-test
git push origin v0.1.0-test
```

- [ ] **Step 2: Monitor the workflow**

Go to `https://github.com/leecode/soundbox/actions` and verify:
- The "Release" workflow triggered
- Each step completed successfully (archive, export, DMG, release)
- A GitHub Release was created with `SoundBox-0.1.0-test.dmg` attached

- [ ] **Step 3: Download and verify the DMG**

Download the DMG from the GitHub Release page. On your Mac:
1. Double-click to mount
2. Drag SoundBox.app to Applications
3. Right-click → Open (first launch bypasses Gatekeeper)
4. Verify the app launches and version shows `0.1.0-test`

- [ ] **Step 4: Clean up test tag (if desired)**

```bash
gh release delete v0.1.0-test --yes
git push origin --delete v0.1.0-test
git tag -d v0.1.0-test
```
