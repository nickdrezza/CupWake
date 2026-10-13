// SPDX-License-Identifier: GPL-3.0-only
import AppKit

@main enum CupWakeApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private let caffeinate = CaffeinateController()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(click)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        caffeinate.onChange = { [weak self] in self?.updateIcon() }
        updateIcon()
    }

    @objc private func click() {
        guard let button = statusItem?.button else { return }
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            let menu = NSMenu()
            let item = menu.addItem(withTitle: "Quit CupWake", action: #selector(quit), keyEquivalent: "q")
            item.target = self
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        } else if caffeinate.isOn {
            caffeinate.stop()
        } else {
            do { try caffeinate.start() }
            catch {
                NSLog("CupWake could not start caffeinate: %@", error.localizedDescription)
                NSSound.beep()
            }
        }
    }

    private func updateIcon() {
        let label = caffeinate.isOn ? "CupWake: On" : "CupWake: Off"
        statusItem?.button?.image = CupIcon.image(isOn: caffeinate.isOn)
        statusItem?.button?.toolTip = label
        statusItem?.button?.setAccessibilityLabel(label)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) { caffeinate.stop() }
}
