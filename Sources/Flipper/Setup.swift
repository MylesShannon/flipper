import AppKit
import ServiceManagement

/// Flipper sets itself up: it offers to move into Applications, then opens at login from there.
enum Setup {
    static let applications = URL(fileURLWithPath: "/Applications/Flipper.app")
    static let relaunchArgument = "relaunched"
    private static let loginItemOffered = "loginItemOffered"

    static var isInApplications: Bool {
        Bundle.main.bundleURL.resolvingSymlinksInPath().path == applications.path
    }

    /// True when the copy in Applications was started and this one should quit.
    static func offerMove() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Move Flipper to Applications?"
        alert.informativeText = "Flipper opens at login from the Applications folder."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: applications.path) { try fm.trashItem(at: applications, resultingItemURL: nil) }
            try fm.copyItem(at: Bundle.main.bundleURL, to: applications)
        } catch {
            let failed = NSAlert()
            failed.messageText = "Flipper couldn't move itself to Applications."
            failed.informativeText = "\(error.localizedDescription)\n\nDrag Flipper into Applications in Finder and open it from there."
            failed.runModal()
            return false
        }
        // A copy macOS opened from a temporary place can't be removed, and that's fine.
        try? fm.trashItem(at: Bundle.main.bundleURL, resultingItemURL: nil)
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.arguments = [relaunchArgument]
        NSWorkspace.shared.openApplication(at: applications, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        return true
    }

    /// Registers the login item the first time Flipper runs from Applications, and never again, so switching
    /// Open at Login off sticks.
    static func registerLoginItemOnce(_ defaults: UserDefaults) {
        guard isInApplications, !defaults.bool(forKey: loginItemOffered) else { return }
        try? SMAppService.mainApp.register()
        defaults.set(true, forKey: loginItemOffered)
    }

    static var opensAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    static func setOpensAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {}
        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }
}
