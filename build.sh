#!/bin/bash
# Builds build/OptionTab.app and signs it.
#   ./build.sh             build only
#   ./build.sh --run       build, quit the running copy, and open the new one from build/
#   ./build.sh --install   build, quit the running copy, copy the app to /Applications, and open it from there.
#                          The installed copy starts at login.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/OptionTab.app

swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/OptionTab" "$APP/Contents/MacOS/OptionTab"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# macOS ties the Accessibility permission to the code signature.
# The Apple Development identity gives the same signature on every build, so the permission stays.
# An ad-hoc signature changes on every build, so macOS asks for the permission again.
IDENTITY=$(security find-identity -v -p codesigning | awk '/Apple Development/ {print $2; exit}')
if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" "$APP"
else
    echo "WARNING: No Apple Development identity found. The app gets an ad-hoc signature." >&2
    echo "WARNING: You must grant the Accessibility permission again after each build." >&2
    codesign --force --sign - "$APP"
fi
echo "Built $APP"

if [ "${1:-}" = "--run" ]; then
    pkill -x OptionTab || true
    sleep 0.5
    open "$APP"
fi

if [ "${1:-}" = "--install" ]; then
    # The login item points to this path. A copy outside the project folder keeps working
    # when you rebuild, move, or delete the project.
    # /Applications is the folder that Spotlight, Raycast, and Alfred always index.
    INSTALLED="/Applications/OptionTab.app"
    pkill -x OptionTab || true
    sleep 0.5
    rm -rf "$INSTALLED"
    ditto "$APP" "$INSTALLED"
    open "$INSTALLED"
    echo "Installed $INSTALLED"
fi
