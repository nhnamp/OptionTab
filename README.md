# OptionTab

<img src="docs/images/05_app_icon.png" alt="OptionTab icon" width="128" align="right">

A macOS menu bar app for the windows of one app. Command-Tab changes the app, as before. Option-Tab shows the titles of the frontmost app's windows on all Spaces, and the release of Option focuses the selected window.

Each row starts with an icon: the website's favicon for a Microsoft Edge window, and the app icon for other apps.

OptionTab needs the Accessibility permission. It never captures the screen, so macOS shows no purple screen-recording indicator. The Edge website icons also need Full Disk Access, because macOS protects Edge's favicon file. Without it, Edge rows show the Edge icon.

![The switcher panel with Edge windows: each row shows the website icon, and the New Tab window shows the Edge icon](docs/images/08_panel_edge.png)

## Requirements
- macOS 14 or later
- Xcode or the Swift 6 command line tools
- Optional: an Apple Development signing identity. With it, the Accessibility permission stays after a rebuild.

## Install
```bash
./build.sh --install
```
This builds the app, copies it to `/Applications`, and opens it. On the first launch, turn on **OptionTab** in **System Settings > Privacy & Security > Accessibility**. The installed copy starts at login.

## Use
| Keys | Result |
|------|--------|
| Option-Tab | Opens the list. The first Tab selects the previous window. |
| Tab or Shift-Tab, with Option held | Selects the next or previous window |
| Release Option | Focuses the selected window |
| Option-Esc | Closes the list. The focus does not change. |

If the menu bar is full, macOS hides the OptionTab icon. Open OptionTab again from Raycast, Spotlight, or Finder to show its menu at the mouse pointer.

## Private APIs
OptionTab uses private macOS functions to find windows on other Spaces and to focus them. If a function is missing, the app falls back to public APIs and lists only the current Space. For this reason, the app cannot go in the App Store.

## Documentation
The [`docs/`](docs/) folder has one file for each step: the feasibility analysis, the switcher, start at login, the icon, the menu on reopen, the install location, and the window icons. Each file lists the test results and the known limits.
