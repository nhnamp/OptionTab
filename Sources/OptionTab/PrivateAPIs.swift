import AppKit
import ApplicationServices

/// Private and deprecated macOS functions. The app finds them at run time with `dlsym`.
/// If a future macOS removes one, its value is nil and the app uses public APIs only.
/// Set the environment variable `OPTIONTAB_PUBLIC_ONLY=1` to force the public-only mode.
enum PrivateAPIs {
    typealias GetWindowFunction = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    typealias CreateWithRemoteTokenFunction = @convention(c) (CFData) -> Unmanaged<AXUIElement>?
    typealias GetProcessForPIDFunction = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    typealias SetFrontProcessFunction = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
    typealias PostEventRecordFunction = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError

    static let isForcedOff = ProcessInfo.processInfo.environment["OPTIONTAB_PUBLIC_ONLY"] == "1"

    /// Gives the window server ID (`CGWindowID`) of an Accessibility window.
    static let getWindow: GetWindowFunction? = load("_AXUIElementGetWindow")
    /// Makes an Accessibility element from a token. This finds windows on other Spaces.
    static let createWithRemoteToken: CreateWithRemoteTokenFunction? = load("_AXUIElementCreateWithRemoteToken")
    static let getProcessForPID: GetProcessForPIDFunction? = load("GetProcessForPID")
    /// Brings a process and one of its windows to the front, on any Space.
    static let setFrontProcess: SetFrontProcessFunction? = load("_SLPSSetFrontProcessWithOptions")
    /// Sends a raw event record to a process.
    static let postEventRecord: PostEventRecordFunction? = load("SLPSPostEventRecordTo")

    static var canFindWindowsOnAllSpaces: Bool { getWindow != nil && createWithRemoteToken != nil }
    static var canFocusAcrossSpaces: Bool { getProcessForPID != nil && setFrontProcess != nil && postEventRecord != nil }

    private static let libraries: [UnsafeMutableRawPointer?] = [
        dlopen("/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices", RTLD_LAZY),
        dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
    ]

    private static func load<T>(_ name: String) -> T? {
        guard !isForcedOff else { return nil }
        _ = libraries
        // -2 is RTLD_DEFAULT: search all loaded libraries.
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }
}
