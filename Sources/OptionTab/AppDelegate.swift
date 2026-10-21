import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = WindowStore()
    private let hotkeys = Hotkeys()
    private lazy var focusTracker = FocusTracker(store: store)
    private var switcher: Switcher?
    private var statusItem: NSStatusItem?
    private let statusLine = NSMenuItem(title: "Starting", action: nil, keyEquivalent: "")
    private let loginItemMenuItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
    /// Shown only while macOS blocks the read of Edge's favicons.
    private let edgeIconsMenuItem = NSMenuItem(title: "Allow Website Icons for Edge…", action: #selector(openFullDiskAccessSettings), keyEquivalent: "")
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A frozen app must not freeze the switcher. Each Accessibility call waits 0.5 s at most.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.5)
        setUpStatusItem()
        LoginItem.registerIfWanted()
        warnIfAltTabRuns()
        startWhenTrusted()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.makeMenuBarIcon()
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        loginItemMenuItem.target = self
        menu.addItem(loginItemMenuItem)
        edgeIconsMenuItem.target = self
        menu.addItem(edgeIconsMenuItem)
        let settingsItem = NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        let quitItem = NSMenuItem(title: "Quit OptionTab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        item.menu = menu
        statusItem = item
    }

    /// A small copy of the app icon: three titles, the middle one selected.
    /// The selected row has a hole for its title. macOS colors a template image to match the menu bar.
    private static func makeMenuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 3, y: 13, width: 8, height: 2), xRadius: 1, yRadius: 1).fill()
            let selectedRow = NSBezierPath(roundedRect: NSRect(x: 1, y: 6, width: 16, height: 6), xRadius: 2, yRadius: 2)
            selectedRow.append(NSBezierPath(roundedRect: NSRect(x: 3.5, y: 8.25, width: 8.5, height: 1.5), xRadius: 0.75, yRadius: 0.75))
            selectedRow.windingRule = .evenOdd
            selectedRow.fill()
            NSBezierPath(roundedRect: NSRect(x: 3, y: 3, width: 6, height: 2), xRadius: 1, yRadius: 1).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "OptionTab"
        return image
    }

    /// Starts at once if the app has the Accessibility permission.
    /// If not, macOS shows its permission prompt, and the app checks again each second.
    private func startWhenTrusted() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options), start() { return }
        statusLine.title = "Waiting for Accessibility permission"
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self, AXIsProcessTrusted(), self.start() else { return }
            timer.invalidate()
        }
    }

    /// Starts the hot keys and the focus observation. Returns false when the event tap cannot start.
    private func start() -> Bool {
        guard hotkeys.start() else { return false }
        switcher = Switcher(store: store, hotkeys: hotkeys)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.appDidActivate(app)
        }
        if let app = NSWorkspace.shared.frontmostApplication {
            appDidActivate(app)
        }
        statusLine.title = PrivateAPIs.canFindWindowsOnAllSpaces
            ? "Ready: Option-Tab lists windows on all Spaces"
            : "Ready: Option-Tab lists windows on this Space only"
        return true
    }

    private func appDidActivate(_ app: NSRunningApplication) {
        guard app.processIdentifier != getpid() else { return }
        focusTracker.follow(app)
        // Search now, so the windows on other Spaces are ready before the next Option-Tab.
        store.searchIfNeeded(for: app) {}
    }

    /// Warns now if AltTab runs, and later if AltTab starts.
    /// At login, AltTab can start after OptionTab, so the check at launch is not sufficient.
    private func warnIfAltTabRuns() {
        let altTabId = "com.lwouis.alt-tab-macos"
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if app?.bundleIdentifier == altTabId { self?.showAltTabWarning() }
        }
        if !NSRunningApplication.runningApplications(withBundleIdentifier: altTabId).isEmpty {
            showAltTabWarning()
        }
    }

    private func showAltTabWarning() {
        showAlert("AltTab is running",
                  "AltTab also uses Option-Tab, so the key press can go to AltTab instead of OptionTab. "
                  + "Quit AltTab, or change its Option-Tab shortcut in AltTab Settings > Controls.")
    }

    private func showAlert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        NSApp.activate()
        alert.runModal()
        // Give the focus back to the previous app, because Option-Tab lists the windows of the frontmost app.
        NSApp.hide(nil)
    }

    /// Opening the app again (Finder, Spotlight, `open`) shows the menu at the mouse.
    /// macOS hides the menu bar item when the menu bar is full, so this is a second way to the menu.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard let menu = statusItem?.menu else { return false }
        // The menu runs its own loop until it closes, so show it after the reopen event returns.
        DispatchQueue.main.async {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
        return false
    }

    /// Shows the current login item state each time the menu opens. The user can change it in System Settings.
    func menuWillOpen(_ menu: NSMenu) {
        edgeIconsMenuItem.isHidden = !WindowIcons.needsEdgeDataAccess
        guard LoginItem.isInstalledCopy else {
            loginItemMenuItem.title = "Start at Login: install first with ./build.sh --install"
            loginItemMenuItem.state = .off
            loginItemMenuItem.isEnabled = false
            return
        }
        loginItemMenuItem.isEnabled = true
        switch LoginItem.status {
        case .enabled:
            loginItemMenuItem.title = "Start at Login"
            loginItemMenuItem.state = .on
        case .requiresApproval:
            loginItemMenuItem.title = "Start at Login: approve in System Settings…"
            loginItemMenuItem.state = .mixed
        default:
            loginItemMenuItem.title = "Start at Login"
            loginItemMenuItem.state = .off
        }
    }

    @objc private func toggleLoginItem() {
        if LoginItem.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return
        }
        do {
            try LoginItem.setEnabled(LoginItem.status != .enabled)
        } catch {
            showAlert("Cannot change the login item", error.localizedDescription)
        }
    }

    @objc private func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
