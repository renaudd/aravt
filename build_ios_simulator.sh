#!/bin/bash
# build_ios_simulator.sh
# Builds a debug iOS simulator bundle and installs it in a running simulator.
#
# Requirements:
#   - Xcode installed with at least the iOS 26.4 simulator runtime
#   - At least one simulator booted (script will auto-boot iPhone 17 if none)
#
# Usage:
#   ./build_ios_simulator.sh                  # installs on booted/default sim
#   ./build_ios_simulator.sh <simulator-udid>  # installs on a specific sim
#
# Output: build/ios/iphonesimulator/Runner.app

set -e
export PATH="/opt/homebrew/bin:$PATH"

# ---- Target simulator -------------------------------------------------------
# You can override the UDID on the command line: ./build_ios_simulator.sh <udid>
TARGET_UDID="${1:-}"

echo ""
echo "============================================="
echo "  Aravt — iOS Simulator Build"
echo "============================================="
echo ""

# Strip extended attributes
echo "[1/4] Stripping extended attributes from source trees..."
find ios/    -exec xattr -c {} + 2>/dev/null || true
find assets/ -exec xattr -c {} + 2>/dev/null || true
find lib/    -exec xattr -c {} + 2>/dev/null || true
find "$HOME/.pub-cache/" -exec xattr -c {} + 2>/dev/null || true

# Build the debug simulator bundle (no --release flag — simulator uses debug)
echo "[2/4] Running flutter build ios --simulator ..."
flutter build ios --simulator --no-tree-shake-icons

APP_PATH="build/ios/iphonesimulator/Runner.app"

if [ ! -d "$APP_PATH" ]; then
    echo ""
    echo "ERROR: Build failed — app bundle not found at $APP_PATH"
    exit 1
fi

echo ""
echo "  Bundle built: $APP_PATH"
echo ""

# ---- Find or boot a simulator -----------------------------------------------
echo "[3/4] Finding a booted simulator..."

BOOTED_UDID=$(xcrun simctl list devices booted -j 2>/dev/null \
    | grep '"udid"' \
    | head -1 \
    | sed 's/.*"\([0-9A-F-]*\)".*/\1/')

if [ -z "$BOOTED_UDID" ]; then
    echo "  No booted simulator found. Booting iPhone 17..."
    # Find the iPhone 17 device UDID from the available devices list
    IPHONE17_UDID=$(xcrun simctl list devices available -j 2>/dev/null \
        | python3 -c "
import sys, json
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if 'iPhone 17 ' not in d.get('name','') and d.get('name','') != 'iPhone 17':
            continue
        if d.get('isAvailable') and not d.get('name','').endswith('Pro') \
           and not d.get('name','').endswith('Pro Max') \
           and not d.get('name','').endswith('Plus') \
           and not d.get('name','').endswith('e'):
            print(d['udid'])
            break
" 2>/dev/null | head -1)

    if [ -z "$IPHONE17_UDID" ]; then
        # Fall back to any available iPhone
        IPHONE17_UDID=$(xcrun simctl list devices available -j 2>/dev/null \
            | python3 -c "
import sys, json
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if 'iPhone' in d.get('name','') and d.get('isAvailable'):
            print(d['udid'])
            sys.exit(0)
" 2>/dev/null | head -1)
    fi

    if [ -z "$IPHONE17_UDID" ]; then
        echo "ERROR: No available iPhone simulator found. Please open Xcode → Window → Devices and Simulators and create one."
        exit 1
    fi

    xcrun simctl boot "$IPHONE17_UDID"
    open -a Simulator
    echo "  Booted simulator: $IPHONE17_UDID"
    BOOTED_UDID="$IPHONE17_UDID"
    # Give simulator time to finish booting
    sleep 5
fi

# Use command-line override if provided
if [ -n "$TARGET_UDID" ]; then
    BOOTED_UDID="$TARGET_UDID"
fi

echo "  Using simulator UDID: $BOOTED_UDID"
echo ""

# ---- Install and launch -----------------------------------------------------
echo "[4/4] Installing and launching on simulator..."
xcrun simctl install   "$BOOTED_UDID" "$APP_PATH"
xcrun simctl launch    "$BOOTED_UDID" com.example.aravt1

echo ""
echo "================================================"
echo "  SUCCESS — Aravt is running in the simulator!"
echo "================================================"
echo ""
echo "  Bundle: $APP_PATH"
echo "  Sim:    $BOOTED_UDID"
echo ""
echo "  To launch again without rebuilding:"
echo "    xcrun simctl launch $BOOTED_UDID com.example.aravt1"
echo ""
