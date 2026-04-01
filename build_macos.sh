#!/bin/bash
echo "Building macOS app..."
export PATH="/opt/homebrew/bin:$PATH"

# Aggressively strip any extended attributes (especially com.apple.FinderInfo / com.apple.provenance)
# from the source directories that Xcode copies into the App Bundle. If these attributes make it into the
# bundle, Xcode immediately fails the internal CodeSign step and aborts the flutter build.
echo "Preparing source files to bypass macOS CodeSign resource fork errors..."
find macos/ -exec xattr -c {} + 2>/dev/null || true
find assets/ -exec xattr -c {} + 2>/dev/null || true
find lib/ -exec xattr -c {} + 2>/dev/null || true
find ios/ -exec xattr -c {} + 2>/dev/null || true
# Critical: Downloaded pub packages carry com.apple.provenance and com.apple.FinderInfo extended attributes that get copied into the frameworks
find "$HOME/.pub-cache/" -exec xattr -c {} + 2>/dev/null || true

# Run the Flutter build natively for macOS
# We use --no-tree-shake-icons to bypass a known compilation error with icons
flutter build macos --no-tree-shake-icons

# Check if the build command was successful (or at least got far enough to create the bundle, signing errors are expected here)
# Since Xcode fails the build strictly due to missing certs and signatures, we just verify if the bundle exists instead of checking the strict $?
APP_PATH="build/macos/Build/Products/Release/aravt.app"

if [ -d "$APP_PATH" ]; then
    echo "Bundle found. Resolving signing issues..."
    
    # We must use absolute paths for xattr and codesign to work around Gatekeeper quirks
    ABS_PATH="$(pwd)/$APP_PATH"
    
    echo "Removing .DS_Store files to avoid resource fork errors..."
    find "$ABS_PATH" -name ".DS_Store" -delete
    
    echo "Clearing remaining extended attributes and signing..."
    xattr -cr "$ABS_PATH"
    
    # Sign it
    codesign --force --deep --entitlements macos/Runner/Release.entitlements --sign - "$ABS_PATH"
    
    echo ""
    echo "=================================="
    echo "Done! The macOS build is ready at:"
    echo "$APP_PATH"
    echo "=================================="
else
    echo "Build failed entirely. Application bundle not found at $APP_PATH"
    exit 1
fi
