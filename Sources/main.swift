import AppKit
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var status: NSStatusItem!
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private let defaults = UserDefaults.standard
    private var policy = ScrollPolicy()
    private var state = "Starting…"

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).count == 1 else {
            NSApp.terminate(nil); return
        }
        defaults.register(defaults: ["enabled": true, "reverseMouse": true, "reverseTrackpad": false,
            "vertical": true, "horizontal": false, "mouseSpeed": 1.0, "continuousAsMouse": false])
        loadPolicy()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "arrow.up.arrow.down.circle", accessibilityDescription: "Scroll Fix")
        let menu = NSMenu(); menu.delegate = self; status.menu = menu
        startTap()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.checkTap() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        if !AXIsProcessTrusted() { showHelp() }
    }

    private func loadPolicy() {
        policy = ScrollPolicy(enabled: defaults.bool(forKey: "enabled"), reverseMouse: defaults.bool(forKey: "reverseMouse"),
            reverseTrackpad: defaults.bool(forKey: "reverseTrackpad"), vertical: defaults.bool(forKey: "vertical"),
            horizontal: defaults.bool(forKey: "horizontal"), mouseSpeed: defaults.double(forKey: "mouseSpeed"),
            continuousAsMouse: defaults.bool(forKey: "continuousAsMouse"))
    }

    private func stopTap() {
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }

    private func startTap() {
        stopTap()
        guard policy.enabled else { state = "Paused"; return }
        guard AXIsProcessTrusted() else { state = "Accessibility permission needed"; return }
        let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context = context else { return Unmanaged.passUnretained(event) }
                let app = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if app.policy.enabled, let tap = app.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                if type == .scrollWheel { app.transform(event) }
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap = tap else { state = "Listener unavailable — check permissions"; return }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        state = "Active"
    }

    private func transform(_ event: CGEvent) {
        policy.apply(to: event)
    }

    private func checkTap() {
        if !policy.enabled { return }
        if !AXIsProcessTrusted() { stopTap(); state = "Accessibility permission needed"; return }
        if let tap = tap, CFMachPortIsValid(tap) {
            if !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
            state = "Active"
        } else { startTap() }
        status.button?.toolTip = "Scroll Fix · \(state)"
    }

    @objc private func woke() { startTap() }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let heading = NSMenuItem(title: "Scroll Fix · \(state)", action: nil, keyEquivalent: "")
        menu.addItem(heading)
        menu.addItem(.separator())
        addToggle(menu, "Enable Scroll Fix", "enabled")
        menu.addItem(.separator())
        addToggle(menu, "Reverse mouse", "reverseMouse")
        addToggle(menu, "Reverse trackpad", "reverseTrackpad")
        menu.addItem(.separator())
        addToggle(menu, "Reverse vertical axis", "vertical")
        addToggle(menu, "Reverse horizontal axis", "horizontal")
        let speed = NSMenuItem(title: "Mouse speed", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for value in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0] {
            let item = NSMenuItem(title: "\(value)×" + (value == 1 ? " (unchanged)" : ""), action: #selector(setSpeed(_:)), keyEquivalent: "")
            item.target = self; item.representedObject = value; item.state = policy.mouseSpeed == value ? .on : .off
            submenu.addItem(item)
        }
        speed.submenu = submenu; menu.addItem(speed)
        addToggle(menu, "Treat unphased smooth scrolling as mouse", "continuousAsMouse")
        menu.addItem(.separator())
        let login = NSMenuItem(title: "Launch at login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self; login.state = SMAppService.mainApp.status == .enabled ? .on : .off; menu.addItem(login)
        addAction(menu, "Open Accessibility Settings…", #selector(openAccessibility))
        addAction(menu, "Restart scroll listener", #selector(woke))
        addAction(menu, "Help & device detection…", #selector(showHelp))
        menu.addItem(.separator())
        addAction(menu, "Quit Scroll Fix", #selector(quit))
    }

    private func addAction(_ menu: NSMenu, _ title: String, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item)
    }
    private func addToggle(_ menu: NSMenu, _ title: String, _ key: String) {
        let item = NSMenuItem(title: title, action: #selector(toggle(_:)), keyEquivalent: "")
        item.target = self; item.representedObject = key; item.state = defaults.bool(forKey: key) ? .on : .off; menu.addItem(item)
    }
    @objc private func toggle(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        defaults.set(!defaults.bool(forKey: key), forKey: key); loadPolicy()
        if key == "enabled" { startTap() }
    }
    @objc private func setSpeed(_ sender: NSMenuItem) {
        defaults.set(sender.representedObject as? Double ?? 1, forKey: "mouseSpeed"); loadPolicy()
    }
    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { alert("Could not change launch at login", error.localizedDescription) }
    }
    @objc private func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc private func showHelp() {
        alert("Scroll Fix", "Quit Scroll Reverser or other scroll modifiers to avoid double reversal.\n\nEnable Scroll Fix in System Settings → Privacy & Security → Accessibility. If it is missing, use + and select ~/Applications/Scroll Fix.app. The listener retries automatically after permission is granted.\n\nBy default, only mouse vertical scrolling is reversed. Axis options apply to the selected devices. Speed affects mouse input even when its reversal is unchecked.\n\nDevice detection uses scroll phases and continuous-event flags. Some smooth-wheel mice, Magic Mouse drivers, remote desktops, and accessibility tools are ambiguous. Enable ‘Treat unphased smooth scrolling as mouse’ if your mouse is detected as a trackpad. Phase-bearing gestures and momentum remain trackpad input.\n\nNo keystrokes are monitored or recorded. macOS 13 or later required.")
    }
    private func alert(_ title: String, _ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = message; alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { stopTap(); timer?.invalidate() }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
