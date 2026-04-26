#!/bin/bash
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  # 从最新 tag 自动获取版本号
  VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
  if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "  e.g. $0 1.0.0"
    exit 1
  fi
fi

echo "==> Building SoundBox $VERSION"

PROJECT="SoundBox.xcodeproj"
SCHEME="SoundBox"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/SoundBox.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/SoundBox-$VERSION.dmg"

# 清理旧构建
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  ARCHS="x86_64 arm64" \
  ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION=1 \
  | tail -1

echo "==> Exporting .app..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist ExportOptions.plist \
  | tail -1

echo "==> Creating DMG..."
mkdir -p "$BUILD_DIR/dmg_temp"
cp -R "$EXPORT_PATH/SoundBox.app" "$BUILD_DIR/dmg_temp/"
ln -s /Applications "$BUILD_DIR/dmg_temp/Applications"
hdiutil create \
  -volname "SoundBox" \
  -srcfolder "$BUILD_DIR/dmg_temp" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$BUILD_DIR/dmg_temp"

SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo ""
echo "==> Done: $DMG_PATH ($SIZE)"
echo "    Mount: open $DMG_PATH"
