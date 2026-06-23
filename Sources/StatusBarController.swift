import Cocoa

/// Manages the menu bar status item and dropdown menu
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var menu: NSMenu!

    /// Observes the status item's `isVisible` so a user ⌘-drag removal is reflected
    /// back into the `hideMenuBarIcon` preference (and the Settings checkbox).
    private var visibilityObservation: NSKeyValueObservation?
    /// Guards against reacting to visibility changes we trigger ourselves via
    /// `setVisible(_:)`, which would otherwise cause a redundant preference write.
    private var isSyncingVisibility = false
    /// Set when the user ⌘-drags the item out of the menu bar. A removed item is
    /// invalidated by AppKit and cannot be restored by setting `isVisible = true`
    /// alone - it must be recreated. This flag tells `setVisible(true)` to do so.
    private var wasRemovedByUser = false

    private let onAppSelected: (MusicApp) -> Void
    private let onVolumeKeysToggled: (Bool) -> Void

    init(onAppSelected: @escaping (MusicApp) -> Void, onVolumeKeysToggled: @escaping (Bool) -> Void) {
        self.onAppSelected = onAppSelected
        self.onVolumeKeysToggled = onVolumeKeysToggled
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        setupStatusItem()

        // Listen for settings changes to keep menu in sync with SwiftUI Settings
        NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: .main) { [weak self] _ in
            self?.buildMenu()
        }
    }

    private func setupStatusItem() {
        // Intentionally NO autosaveName: an autosave name makes AppKit persist the
        // user's ⌘-drag-out (hidden) state and a stale off-menu-bar position, which
        // can park the item off-screen on relaunch. Without it, a freshly created
        // item always defaults to visible and gets a proper menu bar slot.
        //
        // `.removalAllowed` is the documented behavior that lets the user ⌘-drag the
        // item out and makes that removal flip `isVisible` to false (which our KVO
        // observes to sync the Settings checkbox).
        statusItem.behavior = .removalAllowed
        if let button = statusItem.button {
            if let iconPath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png"),
               let icon = NSImage(contentsOfFile: iconPath) {
                icon.isTemplate = true
                icon.size = NSSize(width: 18, height: 18)
                button.image = icon
                #if DEBUG
                print("[StatusBar] loaded MenuBarIcon.png")
                #endif
            } else {
                button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Conduct")
                #if DEBUG
                print("[StatusBar] WARNING: MenuBarIcon.png not found, using fallback")
                #endif
            }
            button.toolTip = L("tooltip")
        }

        observeVisibility()
        buildMenu()
    }

    /// (Re)binds the KVO observation to the current status item. `isVisible` is the
    /// documented signal for a user-initiated ⌘-drag removal from the menu bar.
    private func observeVisibility() {
        visibilityObservation = statusItem.observe(\.isVisible, options: [.new]) { [weak self] item, _ in
            self?.handleVisibilityChange(isVisible: item.isVisible)
        }
    }

    /// Syncs the `hideMenuBarIcon` preference with the item's actual visibility.
    /// Triggered when the user ⌘-drags the icon out (isVisible → false). Writing the
    /// preference updates the Settings checkbox via its `@AppStorage` binding.
    private func handleVisibilityChange(isVisible: Bool) {
        // Ignore visibility changes that we caused ourselves in setVisible(_:).
        guard !isSyncingVisibility else { return }
        // A user-initiated hide (⌘-drag out) invalidates the item; remember so the
        // next show recreates it instead of relying on isVisible alone.
        if !isVisible { wasRemovedByUser = true }
        let shouldHide = !isVisible
        guard Preferences.shared.hideMenuBarIcon != shouldHide else { return }
        Preferences.shared.hideMenuBarIcon = shouldHide
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    private func buildMenu() {
        menu = NSMenu()
        menu.autoenablesItems = false

        // Header
        let headerItem = NSMenuItem(title: L("menu.header"), action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // App selection section
        let controlLabel = NSMenuItem(title: L("menu.control"), action: nil, keyEquivalent: "")
        controlLabel.isEnabled = false
        menu.addItem(controlLabel)

        let selectedApp = Preferences.shared.selectedApp

        // Auto mode first
        let autoItem = NSMenuItem(
            title: MusicApp.auto.displayName,
            action: #selector(appSelected(_:)),
            keyEquivalent: ""
        )
        autoItem.target = self
        autoItem.representedObject = MusicApp.auto
        autoItem.state = (MusicApp.auto == selectedApp) ? .on : .off
        menu.addItem(autoItem)

        menu.addItem(NSMenuItem.separator())

        // Official players
        for app in MusicApp.allCases where app.isOfficialPlayer {
            let item = NSMenuItem(
                title: app.displayName,
                action: app.isInstalled ? #selector(appSelected(_:)) : nil,
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = app
            item.state = (app == selectedApp) ? .on : .off
            item.isEnabled = app.isInstalled
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Third-party players
        for app in MusicApp.allCases where !app.isOfficialPlayer && !app.isBrowserBased && app != .auto {
            let item = NSMenuItem(
                title: app.displayName,
                action: app.isInstalled ? #selector(appSelected(_:)) : nil,
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = app
            item.state = (app == selectedApp) ? .on : .off
            item.isEnabled = app.isInstalled
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Browser-based
        for app in MusicApp.allCases where app.isBrowserBased {
            let item = NSMenuItem(
                title: app.displayName,
                action: #selector(appSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = app
            item.state = (app == selectedApp) ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Volume keys option
        let volumeItem = NSMenuItem(
            title: L("menu.controlVolumeKeys"),
            action: #selector(volumeKeysToggled(_:)),
            keyEquivalent: ""
        )
        volumeItem.target = self
        volumeItem.state = Preferences.shared.controlVolumeKeys ? .on : .off
        menu.addItem(volumeItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at login
        let loginItem = NSMenuItem(
            title: L("menu.launchAtLogin"),
            action: #selector(launchAtLoginToggled(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = Preferences.shared.launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        // Settings (macOS 13+)
        if #available(macOS 13.0, *) {
            let settingsItem = NSMenuItem(
                title: L("menu.settings"),
                action: #selector(openSettings),
                keyEquivalent: ","
            )
            settingsItem.target = self
            menu.addItem(settingsItem)
        }

        // Check for Updates
        let updateItem = NSMenuItem(
            title: L("menu.checkForUpdates"),
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)

        // About
        let aboutItem = NSMenuItem(
            title: L("menu.about"),
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Quit
        let quitItem = NSMenuItem(
            title: L("menu.quit"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func appSelected(_ sender: NSMenuItem) {
        guard let app = sender.representedObject as? MusicApp else { return }
        onAppSelected(app)
        // Update checkmarks
        for item in menu.items {
            if item.representedObject is MusicApp {
                item.state = (item.representedObject as? MusicApp == app) ? .on : .off
            }
        }
    }

    @objc private func volumeKeysToggled(_ sender: NSMenuItem) {
        let newState = sender.state == .off
        sender.state = newState ? .on : .off
        Preferences.shared.controlVolumeKeys = newState
        onVolumeKeysToggled(newState)
    }

    @objc private func launchAtLoginToggled(_ sender: NSMenuItem) {
        let newState = sender.state == .off
        let actual = LaunchAtLoginManager.setEnabled(newState)
        Preferences.shared.setLaunchAtLoginRaw(actual)
        sender.state = actual ? .on : .off
    }

    @objc private func openSettings() {
        if #available(macOS 13.0, *) {
            SettingsWindowController.shared.showWindow()
        }
    }

    @objc private func checkForUpdates(_ sender: NSMenuItem) {
        UpdateController.shared.checkForUpdates(sender)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = L("about.title")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
        alert.informativeText = "Version \(version)\n\n\(L("about.description"))\n\nhttps://github.com/kxdrsrt/conduct-app"
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("about.ok"))

        // Bring app to front for the alert
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Public API

    /// Shows or hides the status item. The checkbox-driven hide/show simply toggles
    /// `isVisible` on the persistent item. However, a *user* ⌘-drag removal invalidates
    /// the item - AppKit will not restore it via `isVisible = true` - so when restoring
    /// after such a removal we recreate the item once (not on every toggle, which would
    /// churn the menu bar host into a zero-height/unplaced state).
    func setVisible(_ visible: Bool) {
        if visible && wasRemovedByUser {
            recreateStatusItem()
            wasRemovedByUser = false
            return
        }
        isSyncingVisibility = true
        statusItem.isVisible = visible
        isSyncingVisibility = false
    }

    /// Tears down the current (user-removed, invalidated) status item and creates a
    /// fresh one in the menu bar. Only used on restore after a ⌘-drag removal.
    private func recreateStatusItem() {
        visibilityObservation = nil
        NSStatusBar.system.removeStatusItem(statusItem)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        isSyncingVisibility = true
        statusItem.isVisible = true
        isSyncingVisibility = false
        setupStatusItem()
    }

    func refreshMenu() {
        buildMenu()
    }
}
