# Feasibility: Option-Tab window switcher without Screen Recording

## What was done
This step analyzes the requirement and tests the system APIs on this Mac (macOS 27.0.1). Small probe programs list windows through the Accessibility API. A throwaway test app checks the list, raise, and unminimize operations. The result: the app is possible, and it needs only the Accessibility permission.

## Files created / modified
| File | Action | Purpose |
|------|--------|---------|
| `docs/02_feasibility_option_tab.md` | Created | Records the requirement analysis, the test results, and the open decisions |

## Requirement
- Command-Tab changes between applications. This is the macOS switcher. The app does not change it.
- Option-Tab shows the windows of the frontmost application. The list shows window titles only. A long title is truncated at the end.
- The app does not use the Screen Recording permission.

## Test results

| Test | Result |
|------|--------|
| Read the window titles of an app with the public Accessibility API | Works. The title comes from `kAXTitleAttribute`. |
| Minimized windows in the list | Works. The list includes them, with `kAXMinimizedAttribute` = true. |
| Window order | `kAXWindowsAttribute` returns the windows in z-order, front to back. |
| Raise a back window and make it the main window | Works. `kAXRaiseAction` and `kAXMainAttribute` move it to the front. |
| Unminimize a window | Works. Set `kAXMinimizedAttribute` to false. |
| Windows on other Spaces, public API | Not visible. The public API found 0 of the 6 windows on other Spaces. |
| Windows on other Spaces, private API `_AXUIElementCreateWithRemoteToken` | Found 6 of 6. Of 8 windows found this way, 7 have a title. |
| Focus a window on another Space | Not tested. The private calls `_SLPSSetFrontProcessWithOptions` and `SLPSPostEventRecordTo` exist on this Mac. AltTab uses them. |

### Limits of these tests
- The probes ran with Screen Recording granted to the terminal. They do not prove the "no Screen Recording" condition directly. The evidence for that condition is different: the Accessibility API needs only the Accessibility permission. AltTab reads titles through `kAXTitleAttribute` and shows them when Screen Recording is off.
- The raise and unminimize tests used a test app that was not frontmost. In the real flow, the target app is frontmost. This case is simpler.
- The hotkey design below follows the AltTab source code. It is not tested in a prototype yet.

## Design

1. **App type.** A menu bar agent (`LSUIElement`). App Sandbox is off. The app cannot go to the Mac App Store.
2. **Permission.** Accessibility only. On first launch, the app asks for it and explains why.
3. **Hotkey.** `RegisterEventHotKey` (Carbon) catches Option-Tab and Option-Shift-Tab. A listen-only `CGEventTap` on `flagsChanged` detects the Option release. AltTab uses the same pattern. Its source says that both keep working during Secure Input (password fields, secure keyboard entry in a terminal).
4. **Window list.** `NSWorkspace.frontmostApplication` gives the app. `kAXWindowsAttribute` gives its windows. Keep only `AXStandardWindow` subroles. The current window is first, so the first Tab press selects the second window.
5. **Panel.** A non-activating `NSPanel` shows one line for each window. The text field uses `lineBreakMode = .byTruncatingTail`. If a title is empty, show the app name and a number, for example "Notes — window 2".
6. **Focus.** On the Option release: unminimize the window if necessary, then send `kAXRaiseAction` and set `kAXMainAttribute`. Esc cancels.

### APIs the app must not call
- ScreenCaptureKit (all of it)
- `CGWindowListCreateImage`
- `CGSHWCaptureWindowList`
- `kCGWindowName` from `CGWindowListCopyWindowInfo`. This key needs Screen Recording. The window IDs and owner PIDs from the same call do not need it.

## Known limits
- **Other Spaces and fullscreen windows.** The public API cannot see them. Each fullscreen window has its own Space. The private API can see them (see the open decision below).
- **Private API cost.** The remote-token search tries element IDs one by one. It takes about 0.1 s for each app. The ID range grows in an app that runs for a long time. Run the search only when `CGWindowListCopyWindowInfo` shows more windows than the public API returns. Cache the result.
- **Native tabs.** An app with native tabs (Finder, Terminal) shows one window for each tab group, with the title of the active tab.
- **Apps with weak Accessibility support.** Some apps (for example, some Java apps and games) return no windows.
- **Private APIs can change** in a future macOS release. The app must check each private symbol with `dlsym` and fall back to the public API.
- **Shortcut conflict.** AltTab uses Option-Tab by default. Quit AltTab or change its shortcut.
- **License.** AltTab is GPL-3.0. Use its techniques. Do not copy its code.

## Alternatives that already exist
- **AltTab, free.** Shortcut 2 (Option-`) shows the windows of the active app by default. With Screen Recording off, it shows titles with app icons in place of screenshots. The titles-only style needs AltTab Pro.
- **macOS Command-`.** This cycles the windows of the frontmost app. It shows no list.
- **macOS App Exposé.** This shows the windows of the frontmost app with thumbnails. It uses a trackpad gesture or a key, not Option-Tab.

## Decisions
1. **Windows on other Spaces.** Option A: public API only. The list shows windows on the current Space and minimized windows. Option B: private API with a public fallback. The list shows all windows of the app. **Decision (2026-10-18): Option B.** This Mac has 3 desktop Spaces, and 6 windows were on other Spaces during the test.
2. **Order across Spaces.** On the current Space, z-order gives a "most recent first" order. For windows on other Spaces, the app tracks focus changes with `AXObserver` to keep the same order. See `03_option_tab_switcher.md`.

## Why it matters
The switcher can work without Screen Recording, because it never needs to look at window content. It needs only window titles and control of windows, and the Accessibility permission covers both. This removes the purple indicator, the DRM flicker, and almost all of the energy cost that the last analysis found in AltTab.

The main decision is about Spaces. Command-Tab moves you to a Space that has a window of the chosen app. With only the public API, Option-Tab then shows only the windows on that Space. The private API fixes this, but it can break in a future macOS update. A fallback to the public API keeps the app usable if that happens.
