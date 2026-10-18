import AppKit
import ApplicationServices

/// Small helpers for the Accessibility API.
enum AX {
    static func copyValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copyValue(element, attribute) as? String
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        copyValue(element, attribute) as? Bool
    }

    static func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        copyValue(element, attribute) as? [AXUIElement] ?? []
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = copyValue(element, attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    /// A normal document or app window. Panels, sheets, and pop-up menus are not standard windows.
    /// macOS reports a minimized window with the subrole `AXDialog`, so a minimized window is also accepted.
    static func isStandardWindow(_ element: AXUIElement) -> Bool {
        string(element, kAXSubroleAttribute) == kAXStandardWindowSubrole || bool(element, kAXMinimizedAttribute) == true
    }

    /// False when the app closed the window or replaced its Accessibility element.
    static func isAlive(_ element: AXUIElement) -> Bool {
        copyValue(element, kAXRoleAttribute) != nil
    }

    /// The window server ID of a window. It is nil in the public-only mode.
    static func windowId(_ element: AXUIElement) -> CGWindowID? {
        guard let getWindow = PrivateAPIs.getWindow else { return nil }
        var id: CGWindowID = 0
        guard getWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }
}
