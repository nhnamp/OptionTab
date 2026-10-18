# Start at login

## What was done
OptionTab now starts at login. The app uses the macOS login item API (`SMAppService.mainApp`). Only an installed copy in `/Applications` or `~/Applications` registers itself. The new `./build.sh --install` command puts a copy in `/Applications`. The status bar menu has a "Start at Login" item that turns the login item on or off. OptionTab now also shows its AltTab warning when AltTab starts after OptionTab.

## Files created / modified
| File | Action | Purpose |
|------|--------|---------|
| `Sources/OptionTab/LoginItem.swift` | Created | Registers and removes the login item. Keeps the choice of the user in `UserDefaults`. |
| `Sources/OptionTab/AppDelegate.swift` | Modified | Registers the login item at launch. Adds the "Start at Login" menu item. Shows the AltTab warning also when AltTab starts later. |
| `build.sh` | Modified | Adds `--install`. It copies the app to `/Applications` and opens it from there. |
| `docs/03_option_tab_switcher.md` | Modified | Points to `--install` and to this file. Updates the AltTab limit. |

## Install
```bash
./build.sh --install
```
The script builds the app, quits the running copy, and copies the app to `/Applications/OptionTab.app`. Then it opens the installed copy. Spotlight, Raycast, and Alfred find apps in `/Applications`. On its first launch, the installed copy registers itself as a login item.

Use `./build.sh --install` again after each change to the code. The login item points to `/Applications/OptionTab.app`, so a copy in `build/` does not start at login.

`./build.sh --run` still opens the copy in `build/`. That copy does not register a login item. Its menu shows "Start at Login: install first with ./build.sh --install".

## Use
| Menu item | Result |
|-----------|--------|
| Start at Login (checkmark) | The login item is on. Click to turn it off. |
| Start at Login (no checkmark) | The login item is off. Click to turn it on. |
| Start at Login: approve in System Settings… | macOS needs your approval. Click to open **System Settings > General > Login Items**. |

The menu reads the state from macOS each time it opens. A change in System Settings shows in the menu.

The app remembers "off". If you turn the login item off, the app does not register it again at the next launch.

### Remove OptionTab
1. Open the OptionTab menu. Click **Start at Login** to remove the checkmark.
2. Click **Quit OptionTab**.
3. Move `/Applications/OptionTab.app` to the Trash.
4. Open **System Settings > General > Login Items**. Make sure that OptionTab is not in the list. If it is there, remove it.

If macOS hides the OptionTab menu bar item, open OptionTab again from Spotlight. The menu opens at the mouse pointer. See [06_menu_on_reopen.md](06_menu_on_reopen.md).

## How it works
1. At launch, `LoginItem.registerIfWanted()` checks the path of the app. A copy outside `/Applications` and `~/Applications` does nothing. This rule stops a test build from becoming the login item.
2. On the first launch of an installed copy, the choice is "on". The app saves this choice in `UserDefaults`.
3. If the choice is "on" and macOS reports `notRegistered` or `notFound`, the app calls `SMAppService.mainApp.register()`.
4. The menu item calls `register()` or `unregister()` and saves the new choice.

macOS ties the Accessibility permission to the bundle ID and the code signature. The installed copy has the same bundle ID and signature as the copy in `build/`, so the permission stays.

### AltTab at login
At login, macOS starts the login items in no fixed order. AltTab can start one second after OptionTab. A check only at launch then finds nothing. For this reason, OptionTab also observes `NSWorkspace.didLaunchApplicationNotification`. It shows the warning when AltTab starts.

## Test results (2026-10-18, macOS 27.0.1)
| Test | Result |
|------|--------|
| `./build.sh --install` | The app is in `/Applications`, it runs from there, and its signature is valid |
| Registration, from the system log | `SMAppService` status 3 (not found), then `register` with error 0, then status 1 (enabled) |
| Path of the login item | `backgroundtaskmanagementd` records `/Applications/OptionTab.app` |
| Move from `~/Applications` to `/Applications` | Toggle off in the old copy (`unregister`, error 0), install the new copy, toggle on in the new copy (`register`, error 0, status 1). The Accessibility permission stays. |
| Menu, read through Accessibility | "Start at Login" has a checkmark |
| Menu toggle off, pressed through Accessibility | `unregister` with error 0, status 0. The checkmark goes away. |
| Menu toggle on, pressed through Accessibility | `register` with error 0, status 1. The checkmark comes back. |
| Accessibility permission of the installed copy | The menu shows "Ready: Option-Tab lists windows on all Spaces". The permission stays. |

## Not tested
- **A real login.** The test did not log out or restart the Mac. The registration is correct, but nobody saw the start after a login.
- **The approval path.** macOS did not ask for approval on this Mac. The test did not show the "approve in System Settings…" item.
- **The AltTab warning at a later start.** The test did not start AltTab, because AltTab then takes Option-Tab.

## Known limits
- **AltTab at login.** On 2026-10-18, AltTab and its data went to the Trash on this Mac, together with its LaunchAgent `com.lwouis.alt-tab-macos`. If you install AltTab again, turn off "Start at login" in AltTab Settings > General, or change the AltTab shortcut. Then AltTab and OptionTab do not both use Option-Tab after a login.
- **Hidden menu bar item.** If the menu bar is full, macOS hides the OptionTab item. Open OptionTab again to show the menu. See [06_menu_on_reopen.md](06_menu_on_reopen.md).
- **One installed path.** The login item points to `/Applications/OptionTab.app`. If you move the app, click **Start at Login** off in the old copy before the move. Then click it on in the moved copy. The move from `~/Applications` to `/Applications` used these steps.

## Why it matters
Before this step, you had to open OptionTab by hand after each restart, which made it easy to forget, and then Option-Tab did nothing. Now the installed copy starts with your session, so Option-Tab works from the first minute.

The install step also separates the copy you use every day from the copy you test. A rebuild in the project folder does not break the copy that starts at login, and a test build cannot take over the login item by accident.
