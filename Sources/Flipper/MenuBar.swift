import AppKit
import FlipperCore

final class MenuBar: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let defaults = UserDefaults.standard
    private lazy var scrollTap = ScrollTap(settings: FlipSettings(defaults: defaults))
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var waitForAccess: Timer?
    // As wide as the column macOS draws the checkmark in, so the column stays when nothing is checked.
    private static let blankCheck = NSImage(size: NSSize(width: 12, height: 1), flipped: false) { _ in true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        item.button?.image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "Flipper")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        if !Setup.isInApplications && Setup.offerMove() { return }
        Setup.registerLoginItemOnce(defaults)
        if !scrollTap.start() {
            // Adds Flipper to the Accessibility list, switched off, and offers to open it.
            AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
            waitForAccess = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                guard let self, scrollTap.start() else { return }
                timer.invalidate()
                refreshIcon()
            }
        }
        refreshIcon()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let s = scrollTap.settings
        menu.removeAllItems()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        menu.addItem(NSMenuItem(title: "Flipper \(version ?? "development build")", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        if !scrollTap.isRunning {
            menu.addItem(NSMenuItem(title: "Needs Accessibility", action: nil, keyEquivalent: ""))
            menu.addItem(action("Open Accessibility Settings…", #selector(openAccessibility)))
            menu.addItem(.separator())
        }
        menu.addItem(.sectionHeader(title: "Flip"))
        menu.addItem(toggle("Mouse", s.mouse, \.mouse))
        menu.addItem(toggle("Trackpad", s.trackpad, \.trackpad))
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Directions"))
        menu.addItem(toggle("Up and Down", s.vertical, \.vertical))
        menu.addItem(toggle("Left and Right", s.horizontal, \.horizontal))
        menu.addItem(.separator())
        if Setup.isInApplications {
            let login = action("Open at Login", #selector(toggleLogin))
            login.state = Setup.opensAtLogin ? .on : .off
            menu.addItem(login)
        } else {
            menu.addItem(action("Move to Applications…", #selector(move)))
        }
        menu.addItem(.separator())
        // Its own action rather than terminate(_:), which macOS 26 gives an icon that shifts the rows around it.
        menu.addItem(action("Quit Flipper", #selector(quit), key: "q"))
    }

    private func toggle(_ title: String, _ on: Bool, _ setting: WritableKeyPath<FlipSettings, Bool>) -> NSMenuItem {
        let item = action(title, #selector(flip(_:)))
        item.state = on ? .on : .off
        item.representedObject = setting
        return item
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        item.offStateImage = Self.blankCheck
        return item
    }

    @objc private func flip(_ sender: NSMenuItem) {
        guard let setting = sender.representedObject as? WritableKeyPath<FlipSettings, Bool> else { return }
        scrollTap.settings[keyPath: setting].toggle()
        scrollTap.settings.save(to: defaults)
        refreshIcon()
    }

    @objc private func toggleLogin() {
        Setup.setOpensAtLogin(!Setup.opensAtLogin)
    }

    @objc private func move() {
        _ = Setup.offerMove()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func refreshIcon() {
        item.button?.appearsDisabled = !(scrollTap.isRunning && scrollTap.settings.flipsAnything)
    }
}
