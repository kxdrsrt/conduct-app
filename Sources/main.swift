import AppKit

// Ensure only one instance of Conduct runs at a time
let bundleID = Bundle.main.bundleIdentifier ?? "com.conduct.app"
let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
if runningApps.count > 1 {
    // Another instance is already running - activate it and quit this one
    if let existing = runningApps.first(where: { $0 != NSRunningApplication.current }) {
        existing.activate(options: .activateIgnoringOtherApps)
    }
    // Ask the already-running instance to surface its splash window. Relaunching
    // an accessory (menu-bar-only) app via Spotlight does not reliably trigger
    // applicationShouldHandleReopen, so signal it explicitly across processes.
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name("com.conduct.app.showSplash"),
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
