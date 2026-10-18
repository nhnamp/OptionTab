# Install location and Git repository

## What was done
`./build.sh --install` now puts OptionTab in `/Applications` in place of `~/Applications`. Raycast, Spotlight, and Alfred find apps in `/Applications`. The login item moved to the new path. The project is now a Git repository on the branch `main`, with a `.gitignore` and a `README.md`. The remote is the private GitHub repository `nhnamp/OptionTab`.

## Files created / modified
| File | Action | Purpose |
|------|--------|---------|
| `build.sh` | Modified | `--install` copies the app to `/Applications` |
| `.gitignore` | Created | Keeps the build output (`.build/`, `build/`, `.swiftpm/`) and `.DS_Store` out of Git |
| `README.md` | Created | Short description, install steps, keys, and a link to `docs/` |
| `docs/04_start_at_login.md` | Modified | Paths changed to `/Applications`. Records the move of the login item. |
| `docs/05_app_icon.md` | Modified | The icon test row uses the new path |
| `docs/06_menu_on_reopen.md` | Modified | The use steps name Raycast and the new path |

## Move the installed app
These steps moved the app from `~/Applications` to `/Applications`. Use them again if you change the install path.
1. In the old copy, click **Start at Login** to remove the checkmark. This removes the login item for the old path.
2. Run `./build.sh --install`. The new copy opens. It does not register itself, because the saved choice is now "off".
3. In the new copy, click **Start at Login** to set the checkmark. This registers the login item for the new path.
4. Move the old copy to the Trash.

`/Applications` belongs to the `admin` group. An admin user can write to it without `sudo`.

## Push a change
```bash
git add -A
git commit -m "Describe the change"
git push
```
The remote uses SSH (`git@github.com:nhnamp/OptionTab.git`). The SSH key in `~/.ssh` gives access.

## Test results (2026-10-18, macOS 27.0.1)
| Test | Result |
|------|--------|
| `./build.sh --install` | The app is in `/Applications` and runs from there |
| Login item after the move | `backgroundtaskmanagementd` records `file:///Applications/OptionTab.app/`. `SMAppService` status 1 (enabled). |
| Accessibility permission after the move | The menu shows "Ready: Option-Tab lists windows on all Spaces" |
| Icon for `/Applications/OptionTab.app` (`NSWorkspace.icon(forFile:)`) | The new icon |
| Launch Services entries | One entry for `/Applications/OptionTab.app`. The entries for the old copy, the `build/` copy, and the AltTab copy in the Trash are removed. |
| `git status` after `git add -A` | Only source, resources, docs, and images. No build output. |
| Scan for personal data and secrets | No email addresses, keys, tokens, or signing IDs in the files |

## Not tested
- **Raycast.** The test tools cannot control Raycast on this Mac. Spotlight indexing is off on this Mac, so Raycast must find the app with its own folder scan. Open Raycast and type "OptionTab" to check the name and the icon. If Raycast shows an old icon, quit Raycast and open it again.
- **A `./build.sh --run` after this step.** `--run` opens the copy in `build/`, and Launch Services then registers that copy again. Raycast can then show two OptionTab entries.

## Why it matters
Raycast and Spotlight look in `/Applications` first, so OptionTab now opens like any other app. That also makes the menu on reopen easy to reach: type "OptionTab" in Raycast and the menu appears.

The Git repository keeps the history of each change, and GitHub keeps a copy off this Mac. The repository is private because the app uses private macOS APIs and has no license file yet. You can make it public later in the repository settings.
