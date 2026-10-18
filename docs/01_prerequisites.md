# Prerequisites check

## What was done
This step checks the toolchain, the hardware, and the system APIs that an AltTab clone needs. A small Swift test program compiles and runs on this Mac. An `xcodebuild` test build succeeds. All public and private window APIs resolve on macOS 27.0.1.

## Files created / modified
| File | Action | Purpose |
|------|--------|---------|
| `docs/01_prerequisites.md` | Created | Records the result of the prerequisites check |

## Results

| Item | Result | Status |
|------|--------|--------|
| macOS | 27.0.1 (build 26A434), Apple M5 Pro, 48 GB RAM | OK |
| Xcode | 27.0 (27A266a), license accepted | OK |
| Swift | 6.4, target `arm64-apple-macosx27.0.0` | OK |
| macOS SDK | macOS 27.0 | OK |
| Code signing | 1 valid "Apple Development" identity | OK |
| Xcode first launch | `-checkFirstLaunchStatus` returns 69. The CoreDevice plug-in does not load. | Warning. macOS builds still succeed. |
| Homebrew, git | Installed | OK |
| XcodeGen | Not installed | Optional |
| AltTab.app | Installed and running | Conflict during development |

### APIs

| API | Use | Status |
|-----|-----|--------|
| `CGWindowListCopyWindowInfo` | List windows | OK |
| `AXUIElement` (Accessibility) | Read window titles, focus and close windows | OK |
| Carbon `RegisterEventHotKey` / `CGEventTap` | Global hotkey | OK |
| `SCScreenshotManager` (ScreenCaptureKit) | Window thumbnails | OK |
| `CGWindowListCreateImage` | Old thumbnail API | Obsolete since macOS 15. Do not use. |
| `_AXUIElementGetWindow` (private) | Map an AX window to a `CGWindowID` | Found |
| `_AXUIElementCreateWithRemoteToken` (private) | Windows on other Spaces | Found |
| `CGSCopySpacesForWindows`, `CGSCopyManagedDisplaySpaces` (private) | Spaces support | Found |
| `CGSHWCaptureWindowList` (private) | Thumbnails of minimized windows and windows on other Spaces | Found |
| `_SLPSSetFrontProcessWithOptions`, `SLPSPostEventRecordTo` (private) | Focus a specific window across Spaces | Found |

## Constraints
- The app needs Accessibility and Screen Recording permission. macOS keys these grants to the code signature. Sign every build with the Apple Development identity and a fixed bundle ID, or the grants reset on each rebuild.
- App Sandbox must be off. Accessibility control of other apps does not work in the sandbox. The app cannot go to the Mac App Store.
- Private APIs can change in a future macOS release.

## Why it matters
The machine has everything needed to build a native Swift app of this type. The private APIs that AltTab uses exist on this macOS version, so the clone can show windows on other Spaces and minimized windows, not only visible ones.

The installed AltTab app listens for the same kind of hotkey. Quit it while you test the new app, or the two apps fight for the key press.

To fix the Xcode first-launch warning, run `sudo xcodebuild -runFirstLaunch` once.
