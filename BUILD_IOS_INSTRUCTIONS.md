# iOS Build Instructions

Two scripts handle all iOS build scenarios from a terminal with no additional
tooling beyond Xcode + Flutter installed.

---

## Quick Reference

| Goal | Command |
|---|---|
| Simulator (no Apple account needed) | `./build_ios_simulator.sh` |
| Simulator on a specific device | `./build_ios_simulator.sh <UDID>` |
| Device bundle (unsigned, ready for Xcode signing) | `./build_ios.sh` |

---

## Script 1 — Simulator Build: `./build_ios_simulator.sh`

**What it does:**
1. Strips macOS extended attributes from source trees (avoids Xcode resource-fork errors)
2. Runs `flutter build ios --simulator` → `build/ios/iphonesimulator/Runner.app`
3. Finds the currently-booted simulator (auto-boots iPhone 17 if none is running)
4. Installs the `.app` bundle and launches the game

**Requirements:** Xcode with iOS 26.4 runtime installed. No Apple account needed.

**Usage:**
```bash
cd /Users/liamrenaud/Development/aravt_mac/aravt

# Default — auto-finds booted sim, boots iPhone 17 if needed
./build_ios_simulator.sh

# Target a specific simulator by UDID
./build_ios_simulator.sh E193096E-BB3B-45C0-8275-593EE48B1960

# Re-launch without rebuilding
xcrun simctl launch E193096E-BB3B-45C0-8275-593EE48B1960 com.example.aravt1
```

**Available simulators (iOS 26.4):**

| Device | UDID | Default Status |
|---|---|---|
| iPhone 17 | `E193096E-BB3B-45C0-8275-593EE48B1960` | Booted |
| iPhone 17 Pro | `09E346BD-4A44-4CA8-9AD5-01E21151C937` | Shutdown |
| iPhone 17 Pro Max | `CD64AC05-DFCB-4F44-96FB-395CE8EB4352` | Shutdown |
| iPhone 17e | `8FC21D15-4AB7-4435-86B0-79B84ABA1D4F` | Shutdown |
| iPhone Air | `3A06835B-D228-4942-BDB3-9DE3D6F68D06` | Shutdown |

List all available sims: `xcrun simctl list devices available`

**Output:** `build/ios/iphonesimulator/Runner.app`

---

## Script 2 — Device Build: `./build_ios.sh`

**What it does:**
1. Strips macOS extended attributes
2. Runs `flutter build ios --no-codesign --release`
3. Cleans `.DS_Store` from the bundle

> **NOT code-signed.** You must sign in Xcode before deploying to a real device.

**Usage:**
```bash
cd /Users/liamrenaud/Development/aravt_mac/aravt
./build_ios.sh
```

**Output:** `build/ios/iphoneos/Runner.app` (~127 MB, unsigned)

---

### Deploying to a Physical iPhone

**Option A — Xcode (works with free Apple ID):**
1. `open ios/Runner.xcworkspace`
2. Runner project → Runner target → **Signing & Capabilities** → set your Team
3. Connect iPhone via USB, trust Mac on device, select device in toolbar
4. **Product → Run** (Cmd+R)

**Option B — Archive for distribution (paid Apple Developer account required):**
After signing is configured: **Product → Archive → Distribute App**

**Option C — ios-deploy:**
```bash
brew install ios-deploy
codesign --force --sign "iPhone Developer: Your Name (TEAMID)" build/ios/iphoneos/Runner.app
ios-deploy --bundle build/ios/iphoneos/Runner.app --debug
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `No valid code signing certificates` | Use `./build_ios.sh` then sign in Xcode |
| No simulator booted | Script auto-boots iPhone 17 |
| xattr resource-fork errors | Already stripped by both scripts |
| Build hangs at Xcode step | Run `cd ios && pod install` first |
| `flutter: command not found` | `export PATH="$HOME/flutter/bin:$PATH"` |

---

## Bundle ID
`com.example.aravt1` — change `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj` if needed.
