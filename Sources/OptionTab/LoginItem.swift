import AppKit
import ServiceManagement

/// Starts OptionTab at login, with the macOS login item API (`SMAppService`).
///
/// Only an installed copy (in /Applications or ~/Applications) registers itself on its first launch.
/// A test build in the project folder does not register itself, so it does not become the login item.
enum LoginItem {
    /// The choice of the user. It is nil until the first launch of an installed copy.
    private static let preferenceKey = "startAtLogin"

    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static var isInstalledCopy: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    /// Registers the login item if the user wants it and it is not registered yet.
    /// On the first launch of an installed copy, the choice is "yes".
    static func registerIfWanted() {
        guard isInstalledCopy else { return }
        let defaults = UserDefaults.standard
        if defaults.object(forKey: preferenceKey) == nil {
            defaults.set(true, forKey: preferenceKey)
        }
        guard defaults.bool(forKey: preferenceKey), status == .notRegistered || status == .notFound else { return }
        do {
            try SMAppService.mainApp.register()
            NSLog("OptionTab: registered the login item, status: \(statusText)")
        } catch {
            NSLog("OptionTab: cannot register the login item: \(error.localizedDescription)")
        }
    }

    /// Turns the login item on or off, and remembers the choice.
    static func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
        UserDefaults.standard.set(isEnabled, forKey: preferenceKey)
    }

    static var statusText: String {
        switch status {
        case .enabled: return "enabled"
        case .requiresApproval: return "requires approval"
        case .notRegistered: return "not registered"
        case .notFound: return "not found"
        @unknown default: return "unknown"
        }
    }
}
