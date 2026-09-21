#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo 'Install Apple Command Line Tools with: xcode-select --install, then run this again.' >&2
  exit 1
fi
APP="$HOME/Applications/Scroll Fix.app"
BUILD="$PWD/build/Scroll Fix.app"
mkdir -p "$BUILD/Contents/MacOS" "$HOME/Applications" "$PWD/build/module-cache"
xcrun swiftc -O -target "$(uname -m)-apple-macos13.0" -module-cache-path "$PWD/build/module-cache" Sources/ScrollPolicy.swift Sources/main.swift -o "$BUILD/Contents/MacOS/ScrollFix" -framework AppKit -framework ApplicationServices -framework ServiceManagement
cat > "$BUILD/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.afshinki.scrollfix</string>
<key>CFBundleName</key><string>Scroll Fix</string>
<key>CFBundleExecutable</key><string>ScrollFix</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier com.afshinki.scrollfix "$BUILD"
# Stop only this app before updating its executable.
if pgrep -x ScrollFix >/dev/null; then
  pkill -x ScrollFix
  for i in {1..30}; do pgrep -x ScrollFix >/dev/null || break; sleep 0.1; done
  if pgrep -x ScrollFix >/dev/null; then echo 'Quit Scroll Fix and try again.' >&2; exit 1; fi
fi
ditto "$BUILD" "$APP"
open "$APP"
echo "Opened $APP. Enable its Accessibility permission on first launch."
