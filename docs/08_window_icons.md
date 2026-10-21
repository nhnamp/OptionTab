# Window icons

## What was done
Each row of the switcher now starts with an icon. For Microsoft Edge, the icon is the favicon of the website in that window. For other apps, the icon is the app icon. OptionTab gets the favicon without a screenshot and without a network request. It reads the URL from the Edge address bar through Accessibility, and then reads the favicon of that page from the favicon file that Edge keeps on this Mac. macOS protects that file, so this feature needs Full Disk Access for OptionTab.

![Edge windows with website icons](images/08_panel_edge.png)

## Files created / modified
| File | Action | Purpose |
|------|--------|---------|
| `Sources/OptionTab/WindowIcons.swift` | Created | Finds the address bar URL of an Edge window. Reads the favicon from Edge's `Favicons` file. Keeps a cache. Checks the access at each Option-Tab. |
| `Sources/OptionTab/SwitcherPanel.swift` | Modified | Adds a 16 pt icon at the start of each row. `setIcon(_:at:)` replaces one icon. |
| `Sources/OptionTab/Switcher.swift` | Modified | Shows the icons at once, then loads the Edge favicons in the background |
| `Sources/OptionTab/ListCommand.swift` | Modified | For Edge, prints the icon of each window and a summary line |
| `Sources/OptionTab/AppDelegate.swift` | Modified | Adds the menu item "Allow Website Icons for Edge…". It shows only while macOS blocks the read. |
| `docs/images/08_panel_edge.png` | Created | The panel with a test Edge instance |
| `docs/images/08_panel_other_app.png` | Created | The panel with a test app |

## Feasibility
| Part | Source | Permission |
|------|--------|------------|
| URL of the Edge window | The address bar is the only text field in the window toolbar. Its value is the full URL. The search reads about 30 elements and takes about 7 ms. | Accessibility (OptionTab has it) |
| Favicon of the page | Edge keeps the favicon of each visited page in the SQLite file `Favicons` in each profile folder, in 16 px and 32 px | Full Disk Access |
| App icon | `NSRunningApplication.icon` | None |

macOS 27 protects `~/Library/Application Support/Microsoft Edge` as app data (TCC service `SystemPolicyAppDataDetailed`). Without permission, macOS refuses the read and shows no prompt. Then Edge windows show the Edge app icon.

These options do not work or were not chosen:
- **Screen capture of the tab icon.** It needs Screen Recording. OptionTab exists to avoid this permission.
- **Accessibility image of the tab icon.** Accessibility gives the position of an image, not its pixels.
- **Download of `https://<site>/favicon.ico`.** It needs no permission, but it sends a request to each website, it fails for sites behind a login or offline, and the icon can differ from the Edge icon. You chose Full Disk Access instead.

## Full Disk Access is optional
| Full Disk Access | Edge rows | Rows of other apps |
|------------------|-----------|--------------------|
| On | The favicon of the website in each window. A window without a website (New Tab, `edge://` pages) shows the Edge icon. | The app icon |
| Off | The Edge icon | The app icon |

OptionTab checks the access at each Option-Tab. If you turn Full Disk Access off while OptionTab runs, the next Option-Tab shows the Edge icon, and the cache of favicons is cleared. All other features need only the Accessibility permission.

## Give the permission
1. Open the OptionTab menu, or open OptionTab again from Raycast.
2. Click **Allow Website Icons for Edge…**. This opens **System Settings > Privacy & Security > Full Disk Access**.
3. Turn on **OptionTab**. If OptionTab is not in the list, click **+** and select `/Applications/OptionTab.app`.
4. If System Settings asks to quit and reopen OptionTab, click **Quit & Reopen**.

After this, the menu item goes away.

## How it works
1. Option-Tab opens the panel at once. Each row shows the last known favicon of the window, or the app icon.
2. For Edge, a background queue finds the address bar of each window and reads its URL. A value without `https://` gets it. Search text, a New Tab page, and `edge://` pages give no URL, so the row keeps the Edge icon.
3. The queue opens each profile's `Favicons` file read-only with `immutable=1`, because Edge holds a lock on the file. The `Default` profile comes first.
4. The query takes the favicon of the exact page first. If the exact page is not in the file, it takes the favicon of another page on the same host. A host can have a different icon on each page, for example Google Docs and Google Sheets.
5. The panel replaces the icons when the lookup ends. If the window list changed during the lookup, the next lookup updates the icons.
6. A favicon stays in a cache for each page URL. Edge writes a new favicon some seconds after the page loads, so a page without a favicon is checked again after 30 s. The cache is cleared at 500 pages.

OptionTab reads only the favicon of the current page of each Edge window. It does not read the history, the cookies, or other Edge data, and it sends nothing over the network.

## Test from Terminal
```bash
.build/release/OptionTab --list <Edge pid>
```
For Edge, the output has the line "Website icons: N of M windows", and each window line shows `{icon: website, 32 px}` or `{icon: app}`.

A command that starts from Terminal uses the permissions of Terminal, not the permissions of OptionTab. So it prints "0 of N" for your Edge profile, also after OptionTab gets Full Disk Access. To use the permissions of OptionTab, start it through macOS:
```bash
open -n -W --stdout /tmp/optiontab-list.txt /Applications/OptionTab.app --args --list <Edge pid>
```

To test with a separate Edge instance and its own profile folder, set `OPTIONTAB_EDGE_DATA_DIR`:
```bash
open -na "Microsoft Edge" --args --user-data-dir=/tmp/edge-test --no-first-run https://www.wikipedia.org/
OPTIONTAB_EDGE_DATA_DIR=/tmp/edge-test .build/release/OptionTab --list <pid of that instance>
```

## Test results (2026-10-21, macOS 27.0.1)
The tests used a separate Edge instance with a new profile folder, so no test read your Edge data.

| Test | Result |
|------|--------|
| Address bar of an Edge window, through Accessibility | Found in 7 ms. The value is the full URL. |
| `--list`, test Edge instance with Wikipedia, GitHub, Tampermonkey, and a New Tab | 3 of 4 windows with a website icon (32 px). The New Tab window has the app icon. Lookup 54 ms. |
| Favicon that Edge had not written yet (Tampermonkey, first seconds) | App icon. The next lookup found the favicon. |
| Panel, first Option-Tab on the test Edge instance | Website icons on the first open. Focus moves to the selected window. |
| Panel, test app (not Edge) | The app icon on each row. Long titles still end with "…". |
| `--list` on your Edge, started through macOS, without Full Disk Access | "Website icons: 0 of 5 windows". macOS refused the read (`SystemPolicyAppDataDetailed`, authValue 0) and showed no prompt. |
| Installed app with its menu open, without Full Disk Access | macOS refused the read with no prompt (authValue 0). So the narrower "access data from other apps" prompt is not available. |
| Menu without Full Disk Access | "Allow Website Icons for Edge…" is in the menu |
| Menu after you turned on Full Disk Access and reopened OptionTab | The item is not in the menu |
| `--list` on your Edge, started through macOS, with Full Disk Access | "Website icons: 4 of 4 windows", all 32 px. Lookup 101 ms in a new process, with an empty cache. The test read only the summary line. |
| `--list` on your Edge, from a process without access to the Edge folder, after the access check at each Option-Tab | "Website icons: 0 of 4 windows". All 4 windows have the app icon. |
| Panel, test app, installed build after the access check | The app icon on each row. Focus moves to the selected window. |

## Not tested
- **The panel with your Edge windows.** The tests did not open the panel on your Edge, because it shows your window titles. You review it.
- **Full Disk Access turned off while OptionTab runs.** The test used a process without access, not a live change in System Settings.
- **Edge Beta, Dev, and Canary.** Only the stable Edge (`com.microsoft.edgemac`) gets website icons. The other channels show the app icon.
- **A dark favicon in Dark Mode.** A black favicon (GitHub) is hard to see on a dark panel. Edge has the same problem in its tab bar.

## Why it matters
With Edge, every window is the same app, so the titles were the only clue. Now each row shows the icon of the site in that window, which makes the right window easier to spot at a glance. Other apps get their own icon, which also confirms which app's windows the panel is listing.

The cost is one permission. Full Disk Access is broad: macOS lets the app read any protected file, not only Edge's favicons. The code reads just the one favicon file, and only on this Mac, with no network. If you would rather not grant it, everything else still works, and Edge rows show the Edge icon.
