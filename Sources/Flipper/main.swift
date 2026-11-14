import AppKit
import ServiceManagement

if CommandLine.arguments.dropFirst().first == "unregister" {
    try? SMAppService.mainApp.unregister()
    exit(0)
}

// Opening it again while it runs starts another copy; only the first stays. A copy that just moved itself to
// Applications starts the new one before it quits.
if !CommandLine.arguments.contains(Setup.relaunchArgument), let id = Bundle.main.bundleIdentifier,
   NSRunningApplication.runningApplications(withBundleIdentifier: id).contains(where: { $0.processIdentifier != getpid() }) {
    exit(0)
}

let app = NSApplication.shared
let menuBar = MenuBar()
app.delegate = menuBar
app.run()
