import AppKit
import ServiceManagement

if CommandLine.arguments.dropFirst().first == "unregister" {
    try? SMAppService.mainApp.unregister()
    exit(0)
}

// Opening it again while it runs starts another copy, which hands over to the first by reopening it and quits. A copy
// that just moved itself to Applications starts the new one before it quits.
if !CommandLine.arguments.contains(Setup.relaunchArgument), let id = Bundle.main.bundleIdentifier,
   let running = NSRunningApplication.runningApplications(withBundleIdentifier: id)
       .first(where: { $0.processIdentifier != getpid() }) {
    guard let url = running.bundleURL else { exit(0) }
    NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in exit(0) }
    dispatchMain()
}

let app = NSApplication.shared
let menuBar = MenuBar()
app.delegate = menuBar
app.run()
