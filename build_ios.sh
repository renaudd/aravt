#!/bin/bash
# build_ios.sh
# Builds a release iOS app bundle for physical iPhone/iPad deployment.
#
# IMPORTANT: This build is NOT code-signed. Before you can deploy to a real
# device you must sign it via Xcode (open ios/Runner.xcworkspace → Runner
# target → Signing & Capabilities → set your Team) or with ios-deploy after
# manual signing. See the instructions in BUILD_IOS_INSTRUCTIONS.md.
#
# Usage:  ./build_ios.sh
# Output: build/ios/iphoneos/Runner.app  (127 MB, unsigned)

set -e
export PATH="/opt/homebrew/bin:$PATH"

echo ""
echo "============================================"
echo "  Aravt — iOS Device Build (no codesign)"
echo "============================================"
echo ""

# Strip extended attributes that can trip up the Xcode build phase
echo "[1/3] Stripping extended attributes from source trees..."
find ios/    -exec xattr -c {} + 2>/dev/null || true
find assets/ -exec xattr -c {} + 2>/dev/null || true
find lib/    -exec xattr -c {} + 2>/dev/null || true
find "$HOME/.pub-cache/" -exec xattr -c {} + 2>/dev/null || true

# Run the Flutter device build without codesigning so no Apple cert is required
echo "[2/3] Running flutter build ios --no-codesign --release ..."
flutter build ios --no-codesign --release --no-tree-shake-icons

APP_PATH="build/ios/iphoneos/Runner.app"

if [ ! -d "$APP_PATH" ]; then
    echo ""
    echo "ERROR: Build failed — app bundle not found at $APP_PATH"
    exit 1
fi

echo "[3/3] Cleaning .DS_Store files from bundle..."
find "$APP_PATH" -name ".DS_Store" -delete

echo ""
echo "=============================================="
echo "  SUCCESS — iOS device bundle ready:"
echo "  $APP_PATH"
echo "=============================================="
echo ""
echo "  To install on a connected iPhone via Xcode:"
echo "    1. open ios/Runner.xcworkspace"
echo "    2. Set your Development Team in Runner → Signing & Capabilities"
echo "    3. Product → Run (or Archive for distribution)"
echo ""
echo "  To install directly with ios-deploy (after re-signing):"
echo "    ios-deploy --bundle $APP_PATH --debug"
echo ""
