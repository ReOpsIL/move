#!/bin/bash
# Builds "Chess Move.app" into ./build (release, ad-hoc signed, Stockfish bundled).
# Usage: scripts/build_app.sh [--install]   (--install copies the app to /Applications)
set -euo pipefail
cd "$(dirname "$0")/.."
APP="build/Chess Move.app"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/ChessMove"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ChessMove"
cp Resources/puzzles.csv "$APP/Contents/Resources/"

# Bundle Stockfish so the app is self-contained.
SF="${STOCKFISH:-$(command -v stockfish || true)}"
if [ -n "$SF" ]; then
  cp "$(readlink -f "$SF")" "$APP/Contents/Resources/stockfish"
  chmod +x "$APP/Contents/Resources/stockfish"
else
  echo "warning: stockfish not found (brew install stockfish); the app will look for it at runtime" >&2
fi

# Icon
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
swift scripts/make_icon.swift "$ICONSET" >/dev/null 2>&1 && iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" || echo "warning: icon generation failed" >&2

VERSION="1.0.0"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Chess Move</string>
  <key>CFBundleDisplayName</key><string>Chess Move</string>
  <key>CFBundleIdentifier</key><string>local.chessmove.app</string>
  <key>CFBundleExecutable</key><string>ChessMove</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.education</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP/Contents/Resources/stockfish" 2>/dev/null || true
codesign --force --deep --sign - "$APP"
echo "Built: $APP"

if [ "${1:-}" = "--install" ]; then
  pkill -x ChessMove 2>/dev/null || true
  rm -rf "/Applications/Chess Move.app"
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/Chess Move.app"
  open "/Applications/Chess Move.app"
fi
