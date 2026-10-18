import AppKit

if CommandLine.arguments.dropFirst().first == "--list" {
    ListCommand.run(arguments: Array(CommandLine.arguments.dropFirst(2)))
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
