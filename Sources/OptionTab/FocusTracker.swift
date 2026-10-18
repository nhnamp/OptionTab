import AppKit
import ApplicationServices

/// Tells the store which window has the focus, so the list is in "most recent first" order.
/// It observes only the frontmost app, and moves to the new app at each app switch.
final class FocusTracker {
    private let store: WindowStore
    private var observer: AXObserver?

    init(store: WindowStore) {
        self.store = store
    }

    /// Observes the focused window of this app, and stops the observation of the previous app.
    func follow(_ app: NSRunningApplication) {
        stop()
        // The public-only mode has no window IDs. It uses the front-to-back order of the windows instead.
        guard PrivateAPIs.getWindow != nil else { return }
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        if let focused = AX.element(appElement, kAXFocusedWindowAttribute) {
            record(focused)
        }

        var newObserver: AXObserver?
        guard AXObserverCreate(pid, focusedWindowChanged, &newObserver) == .success, let newObserver else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard AXObserverAddNotification(newObserver, appElement, kAXFocusedWindowChangedNotification as CFString, refcon) == .success else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .defaultMode)
        observer = newObserver
    }

    fileprivate func record(_ window: AXUIElement) {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success, let id = AX.windowId(window) else { return }
        store.noteFocused(pid: pid, windowId: id)
    }

    private func stop() {
        guard let observer else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        self.observer = nil
    }
}

private func focusedWindowChanged(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    Unmanaged<FocusTracker>.fromOpaque(refcon).takeUnretainedValue().record(element)
}
