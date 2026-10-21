# OptionTab: the Option-Tab window switcher

## What was done
OptionTab is a menu bar app. Option-Tab shows the titles of the frontmost app's windows on all Spaces, and the release of Option focuses the selected window. The app needs the Accessibility permission. It never captures the screen. The Edge website icons (see [08_window_icons.md](08_window_icons.md)) also need Full Disk Access. A live test on this Mac drives the app with synthetic key presses on a throwaway test app.

![The switcher panel](images/03_switcher_panel.png)

## Files created / modified
| File | Action | Purpose |
|------|--------|---------|
| `Package.swift` | Created | Swift package definition (macOS 14 or later, Swift 5 language mode) |
| `Resources/Info.plist` | Created | App bundle data. `LSUIElement` hides the Dock icon. |
| `build.sh` | Created | Builds and signs `build/OptionTab.app`. `--run` also opens it. |
| `Sources/OptionTab/main.swift` | Created | Entry point. Starts the app, or runs `--list`. |
| `Sources/OptionTab/AppDelegate.swift` | Created | Status bar item, permission flow, AltTab warning, startup |
| `Sources/OptionTab/Hotkeys.swift` | Created | Carbon hot keys for Option-Tab, Option-Shift-Tab, Option-Esc. Event tap for the Option release. |
| `Sources/OptionTab/Switcher.swift` | Created | Switch logic: open, move, cancel, focus |
| `Sources/OptionTab/SwitcherPanel.swift` | Created | The title list. Long titles are truncated at the end. |
| `Sources/OptionTab/WindowStore.swift` | Created | Finds the windows of an app on all Spaces, keeps the cache, sorts by focus order |
| `Sources/OptionTab/FocusTracker.swift` | Created | Records focus changes in the frontmost app |
| `Sources/OptionTab/Focus.swift` | Created | Brings a window to the front, also on another Space |
| `Sources/OptionTab/AX.swift` | Created | Helpers for the Accessibility API |
| `Sources/OptionTab/PrivateAPIs.swift` | Created | Finds private functions with `dlsym`. Gives the public-only fallback. |
| `Sources/OptionTab/ListCommand.swift` | Created | `--list` command for tests from Terminal |
| `docs/02_feasibility_option_tab.md` | Modified | Records the decision for windows on all Spaces |
| `docs/images/03_switcher_panel.png` | Created | Screenshot of the panel from the live test |

## Build and run
```bash
./build.sh --run
```
This opens a test copy from `build/`. For daily use, run `./build.sh --install`. The installed copy starts at login. See [04_start_at_login.md](04_start_at_login.md).

The script signs the app with the Apple Development identity. macOS ties the Accessibility permission to this signature, so the permission stays after a rebuild. If no identity exists, the script uses an ad-hoc signature and prints a warning. Then you must grant the permission again after each build.

On the first launch, macOS asks for the Accessibility permission:
1. Open **System Settings > Privacy & Security > Accessibility**. The status bar menu of OptionTab has a shortcut to this page.
2. Turn on **OptionTab**.
3. OptionTab checks the permission each second and starts by itself. This step is not tested yet. If the menu still shows "Waiting for Accessibility permission" after you turn the permission on, quit OptionTab and open it again.

The status bar menu shows the state: "Waiting for Accessibility permission" or "Ready".

## Use
| Keys | Result |
|------|--------|
| Command-Tab | Changes the app. This is the macOS switcher. |
| Option-Tab | Opens the list of windows of the frontmost app. The first Tab selects the window that had the focus before the current one. |
| Tab, with Option held | Selects the next window |
| Shift-Tab, with Option held | Selects the previous window |
| Release Option | Focuses the selected window. A minimized window is restored. |
| Option-Esc | Closes the list. The focus does not change. |
| Fast Option-Tab tap | Switches to the previous window without the list |

## How it works
1. **Window list.** The public Accessibility API returns the windows on the current Space and the minimized windows. The private `_AXUIElementCreateWithRemoteToken` search finds the windows on other Spaces. The search runs on a background queue, with a time limit of 0.5 s. It starts when an app becomes frontmost, so the result is usually ready before Option-Tab.
2. **Cache.** The store keeps each window that it sees or finds, by window ID. A new search starts only when the set of unresolved window IDs changes. Helper windows that never resolve do not start a search on each key press.
3. **Order.** The focused window is first. Then the other windows follow in the order of the last focus. `FocusTracker` observes only the frontmost app.
4. **Focus.** `_SLPSSetFrontProcessWithOptions` brings the window forward and moves to its Space. A synthetic event record makes the window key. The layout comes from yabai (MIT license). Then `kAXRaiseAction` raises the window.
5. **Fallback.** If a private function is missing, the app uses only public APIs. The list then shows only the current Space and minimized windows. The status bar menu says so.

### APIs the app does not call
ScreenCaptureKit, `CGWindowListCreateImage`, `CGSHWCaptureWindowList`, and `kCGWindowName`. For this reason, the app needs no Screen Recording permission.

## Test from Terminal
```bash
build/OptionTab.app/Contents/MacOS/OptionTab --list
```
This prints the windows that Option-Tab shows for the frontmost app. Add a process ID to test another app. Set `OPTIONTAB_PUBLIC_ONLY=1` to force the public-only mode.

A command that starts from Terminal uses the permissions of Terminal, not the permissions of OptionTab.

## Test results (2026-10-18, macOS 27.0.1)
| Test | Result |
|------|--------|
| `--list` on real apps, all-Spaces mode | Edge 4 windows, Claude 2 windows |
| `--list`, public-only mode | Edge 2 windows, Claude 0 windows (only the current Space) |
| Option-Tab, one Tab, release | Focus moves to the previous window |
| Two Tabs | Focus moves to the third window |
| Option-Esc | Focus does not change |
| Fast tap | Focus moves to the previous window. The panel does not stay open. |
| Shift-Tab to a minimized window | The window is restored and focused |
| Focus order after switches | Most recent first |
| Long title | Truncated at the end with "…" |
| Public-only mode, live | One Tab, fast tap, and Shift-Tab to a minimized window all work |
| Launch without permission | The app waits and does not crash |
| Idle use after 30 s | 0.0% CPU, 0 idle wakeups, 13 MB memory |

## Known limits
- **Focus on another Space is not tested live.** The test moves the screen to another Space. The same private call works for windows on the current Space.
- **Panel over a fullscreen app** is not tested.
- **Start at login.** An installed copy starts at login. See [04_start_at_login.md](04_start_at_login.md).
- **AltTab conflict.** AltTab also uses Option-Tab, and macOS does not report the conflict. OptionTab shows a warning at launch when AltTab runs, and also when AltTab starts later. Quit AltTab, or change its Option-Tab shortcut in AltTab Settings > Controls.
- **Secure Input.** AltTab's source says that Carbon hot keys and `flagsChanged` taps work during Secure Input. This is not tested for OptionTab.
- **Search time limit.** In an app that runs for a long time, the search can stop before it finds a window. The window appears in the list after the app becomes frontmost once on the Space of that window.
- **Maximum 20 windows** for each app in the list.
- **Native tabs.** An app with native tabs (Finder, Terminal) shows one line for each tab group.
- **Weak Accessibility support.** Some apps (for example, some Java apps and games) show no windows.
- **Private APIs can change** in a future macOS release. The app then falls back to the public API.
- **No App Store.** App Sandbox is off, because the Accessibility control of other apps does not work in the sandbox.

## Why it matters
This is the first working version of the app. Command-Tab still changes apps, and Option-Tab now changes windows inside the app, on every Space, with titles only. Because the app reads titles through Accessibility and never takes screenshots, there is no purple screen-recording indicator, and the idle cost is close to zero: 13 MB of memory, against 134 MB for AltTab.

The jump to a window on another Space is not tested yet, because the test moves the screen to another Space. Try it first in normal use.
