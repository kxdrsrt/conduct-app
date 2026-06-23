import Cocoa
import Carbon
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController!
    private var mediaKeyTap: MediaKeyTap!
    private var musicController: (any MusicControllerProtocol)?
    private var autoController: AutoController? // Cached to preserve sticky resolution
    private var hotkeyRef: EventHotKeyRef?
    private var hotkeyHandlerRef: EventHandlerRef?

    // Double-tap detection (only accessed on main queue)
    private var lastNextTapTime: Date = .distantPast
    private var lastPrevTapTime: Date = .distantPast
    private let doubleTapInterval: TimeInterval = 0.4

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        print("[AppDelegate] applicationDidFinishLaunching - starting")
        #endif
        // Install a minimal main menu so standard shortcuts (⌘Q to quit) work
        // whenever the app is active - e.g. while the Settings window is focused.
        setupMainMenu()

        // Initialize preferences with defaults
        Preferences.shared.registerDefaults()

        // Reconcile the stored launch-at-login preference with the real system
        // state (the user may have toggled it in System Settings while we were off).
        LaunchAtLoginManager.synchronize()

        // Set up the music controller for the selected app
        updateMusicController()

        // Set up status bar
        statusBarController = StatusBarController(
            onAppSelected: { [weak self] app in
                Preferences.shared.selectedApp = app
                self?.updateMusicController()
            },
            onVolumeKeysToggled: { [weak self] enabled in
                Preferences.shared.controlVolumeKeys = enabled
                self?.mediaKeyTap.setInterceptVolumeKeys(enabled)
            }
        )

        // Set up media key interception
        mediaKeyTap = MediaKeyTap(delegate: self)
        mediaKeyTap.setInterceptVolumeKeys(Preferences.shared.controlVolumeKeys)
        // Listen for settings changes from SwiftUI Settings window
        NotificationCenter.default.addObserver(self,
            selector: #selector(settingsDidChange),
            name: .settingsChanged,
            object: nil)

        // Listen for wake notifications (play on wake)
        NSWorkspace.shared.notificationCenter.addObserver(self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil)

        // Listen for cycle target app hotkey
        NotificationCenter.default.addObserver(self,
            selector: #selector(cycleTargetApp),
            name: .cycleTargetApp,
            object: nil)

        // Listen for relaunch requests from a second instance (e.g. Spotlight)
        // so we can surface the splash window when the app is reopened.
        DistributedNotificationCenter.default().addObserver(self,
            selector: #selector(handleShowSplashRequest),
            name: Notification.Name("com.conduct.app.showSplash"),
            object: nil)

        // Register global hotkey
        registerGlobalHotkey()

        // Apply hide menu bar icon preference
        updateMenuBarVisibility()

        // Show onboarding first if needed, then request permissions after completion.
        // If onboarding was already completed, go straight to permission check.
        if #available(macOS 13.0, *), !OnboardingWindowController.shared.hasCompletedOnboarding {
            OnboardingWindowController.shared.show { [weak self] in
                self?.checkAccessibilityPermission()
                self?.showSplashIfNeeded()
            }
        } else {
            checkAccessibilityPermission()
            #if DEBUG
            print("[AppDelegate] onboarding complete, calling showSplashIfNeeded")
            #endif
            if #available(macOS 13.0, *) {
                showSplashIfNeeded()
            }
        }
    }

    @available(macOS 13.0, *)
    private func showSplashIfNeeded() {
        #if DEBUG
        print("[AppDelegate] showSplashIfNeeded: showSplashOnLaunch=\(Preferences.shared.showSplashOnLaunch)")
        #endif
        guard Preferences.shared.showSplashOnLaunch else { return }
        SplashWindowController.shared.show()
    }

    @objc private func settingsDidChange() {
        updateMusicController()
        mediaKeyTap.setInterceptVolumeKeys(Preferences.shared.controlVolumeKeys)
        registerGlobalHotkey()
        updateMenuBarVisibility()
    }

    private func updateMusicController() {
        let app = Preferences.shared.selectedApp
        if app == .auto {
            // Reuse cached AutoController to preserve sticky resolution
            if autoController == nil {
                autoController = AutoController()
            }
            musicController = autoController
        } else {
            autoController = nil
            musicController = MusicControllerFactory.controller(for: app)
        }
    }

    // MARK: - Main Menu

    /// Builds a minimal application main menu. AppKit routes the standard ⌘Q key
    /// equivalent through the main menu, so without this the shortcut does nothing
    /// when one of the app's windows (Settings, splash) is focused.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appName = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "Conduct"
        let appMenu = NSMenu(title: appName)
        appMenu.addItem(
            withTitle: L("menu.close"),
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: L("menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu Bar Visibility

    private func updateMenuBarVisibility() {
        let hide = Preferences.shared.hideMenuBarIcon
        #if DEBUG
        print("[AppDelegate] updateMenuBarVisibility: hide=\(hide)")
        #endif

        // Only touch activation policy when the icon is being shown (hide=false).
        // When hiding, leave the policy as-is - the app runs silently without
        // forcing a Dock icon. Windows set .regular themselves when shown, and
        // windowWillClose restores .accessory when the last window is dismissed.
        if #available(macOS 13.0, *) {
            if !hide {
                let settingsOpen = SettingsWindowController.shared.isWindowVisible
                let splashOpen = SplashWindowController.shared.isWindowVisible
                if !settingsOpen && !splashOpen {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }

        statusBarController?.setVisible(!hide)
    }

    // Called when the user clicks the Dock icon (only visible when menu bar icon is hidden).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            if !flag {
                SplashWindowController.shared.show()
            }
        }
        return false
    }

    // Triggered when a second instance is launched (e.g. via Spotlight) while the
    // app is already running in the menu bar. Surfaces the splash window.
    @objc private func handleShowSplashRequest() {
        if #available(macOS 13.0, *) {
            DispatchQueue.main.async {
                SplashWindowController.shared.show()
            }
        }
    }

    // MARK: - Play on Wake

    @objc private func systemDidWake(_ notification: Notification) {
        guard Preferences.shared.playOnWake else { return }
        // Small delay for audio system to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.musicController?.playPause()
        }
    }

    // MARK: - Global Hotkey

    private func registerGlobalHotkey() {
        // Unregister existing hotkey and handler
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = hotkeyHandlerRef {
            RemoveEventHandler(handler)
            hotkeyHandlerRef = nil
        }

        guard Preferences.shared.globalHotkeyEnabled else { return }

        let keyCode = UInt32(Preferences.shared.globalHotkeyKeyCode)
        let modifiers = UInt32(Preferences.shared.globalHotkeyModifiers)

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434F4E44) // "COND"
        hotKeyID.id = 1

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr else { return }
        hotkeyRef = ref

        // Install handler (tracked so we can remove it later)
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var handlerRef: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) -> OSStatus in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .cycleTargetApp, object: nil)
            }
            return noErr
        }, 1, &eventSpec, nil, &handlerRef)
        hotkeyHandlerRef = handlerRef
    }

    @objc private func cycleTargetApp() {
        let allApps = MusicApp.allCases.filter { $0 != .auto }
        let current = Preferences.shared.selectedApp
        guard let idx = allApps.firstIndex(of: current) else {
            // Currently in Auto mode - cycle to first app
            if let first = allApps.first {
                Preferences.shared.selectedApp = first
                updateMusicController()
                statusBarController?.refreshMenu()
                if Preferences.shared.notifyOnSwitch {
                    showSwitchNotification(to: first)
                }
            }
            return
        }
        let nextIdx = (idx + 1) % allApps.count
        let nextApp = allApps[nextIdx]
        Preferences.shared.selectedApp = nextApp
        updateMusicController()
        statusBarController?.refreshMenu()

        if Preferences.shared.notifyOnSwitch {
            showSwitchNotification(to: nextApp)
        }
    }

    // MARK: - Pause Others

    /// Whether the given controller targets a browser-based app (e.g. YouTube).
    /// Browser-based targets are independent and shouldn't trigger pausing native players.
    private func isBrowserBasedController(_ controller: any MusicControllerProtocol) -> Bool {
        if controller is YouTubeController { return true }
        if let auto = controller as? AutoController,
           let resolved = auto.resolvedBundleIdentifier,
           resolved == "youtube" {
            return true
        }
        return false
    }

    private func pauseOtherApps(except target: any MusicControllerProtocol) {
        guard Preferences.shared.pauseOthersOnPlay else { return }

        // Get the effective bundle ID - for AutoController, use the resolved target
        let targetBundle: String
        if let auto = target as? AutoController,
           let resolved = auto.resolvedBundleIdentifier {
            targetBundle = resolved
        } else {
            targetBundle = target.bundleIdentifier
        }

        for app in MusicApp.allCases where app != .auto && app.rawValue != targetBundle {
            if app.isBrowserBased { continue }
            guard NSRunningApplication.runningApplications(withBundleIdentifier: app.rawValue).first != nil else { continue }

            let appName: String
            switch app {
            case .appleMusic: appName = "Music"
            case .spotify: appName = "Spotify"
            case .doppler: appName = "Doppler"
            case .vox: appName = "VOX"
            case .swinsian: appName = "Swinsian"
            case .cider: appName = "Cider"
            case .daftCloud: appName = "DaftCloud"
            default: continue
            }

            appleScriptQueue.async {
                let script = NSAppleScript(source: """
                    if application "\(appName)" is running then
                        tell application "\(appName)"
                            if player state is playing then pause
                        end tell
                    end if
                """)
                var error: NSDictionary?
                script?.executeAndReturnError(&error)
            }
        }
    }

    // MARK: - Switch Notification

    private func showSwitchNotification(to app: MusicApp) {
        guard Preferences.shared.notifyOnSwitch else { return }
        let content = UNMutableNotificationContent()
        content.title = "Conduct"
        content.body = "Now routing media keys to \(app.displayName)"
        let request = UNNotificationRequest(identifier: "conduct-switch", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Accessibility

    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        if trusted {
            mediaKeyTap.start()
            triggerAutomationPermission()
        } else {
            promptForAccessibility()
        }
    }

    private func promptForAccessibility() {
        // Show prompt and open System Settings
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Poll for permission grant (stop after 5 minutes to avoid resource leak)
        var attempts = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            attempts += 1
            if AXIsProcessTrusted() {
                timer.invalidate()
                self?.mediaKeyTap.start()
                self?.triggerAutomationPermission()
            } else if attempts >= 300 {
                timer.invalidate()
            }
        }
    }

    /// Sends a harmless AppleScript to the selected music app to trigger
    /// the macOS Automation permission prompt early (on launch rather than first key press)
    private func triggerAutomationPermission() {
        let app = Preferences.shared.selectedApp
        guard app != .auto && app != .youtube else { return }

        let appName: String
        switch app {
        case .appleMusic: appName = "Music"
        case .spotify: appName = "Spotify"
        case .doppler: appName = "Doppler"
        case .vox: appName = "VOX"
        case .swinsian: appName = "Swinsian"
        case .cider: appName = "Cider"
        case .daftCloud: appName = "DaftCloud"
        default: return
        }

        appleScriptQueue.async {
            // A no-op query that triggers the permission prompt without side effects
            let script = NSAppleScript(source: """
                if application "\(appName)" is running then
                    tell application "\(appName)" to get name
                end if
            """)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
        }
    }
}

// MARK: - MediaKeyTapDelegate

extension AppDelegate: MediaKeyTapDelegate {
    func mediaKeyTap(_ tap: MediaKeyTap, receivedEvent event: MediaKeyEvent) {
        guard let controller = musicController else { return }

        // For play/pause, launch the app if it's not running
        if case .playPause = event, !controller.isRunning {
            // Only pause other apps for native players (not browser-based like YouTube)
            if !isBrowserBasedController(controller) {
                pauseOtherApps(except: controller)
            }
            launchApp(controller.bundleIdentifier)
            // Poll until app is running, then send play (max 10s)
            var pollCount = 0
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                pollCount += 1
                if controller.isRunning {
                    timer.invalidate()
                    controller.playPause()
                } else if pollCount >= 20 {
                    timer.invalidate()
                }
            }
            return
        }

        // For other commands, only send if app is running
        guard controller.isRunning else { return }

        switch event {
        case .playPause:
            controller.playPause()
            // Only pause other apps for native players (not browser-based like YouTube)
            if !isBrowserBasedController(controller) {
                pauseOtherApps(except: controller)
            }
        case .next:
            handleNextKey(controller: controller)
        case .previous:
            handlePreviousKey(controller: controller)
        case .volumeUp:
            controller.volumeUp()
        case .volumeDown:
            controller.volumeDown()
        case .mute:
            controller.mute()
        }
    }

    // MARK: - Double-Tap Handling

    private func handleNextKey(controller: any MusicControllerProtocol) {
        let now = Date()
        let action = Preferences.shared.doubleTapAction

        if action != "none" && now.timeIntervalSince(lastNextTapTime) < doubleTapInterval {
            // Double-tap detected - first tap already sent one skip, send one more = 2 total
            lastNextTapTime = .distantPast
            switch action {
            case "skipTwo":
                controller.nextTrack()
            default:
                controller.nextTrack()
            }
        } else {
            lastNextTapTime = now
            controller.nextTrack()
        }
    }

    private func handlePreviousKey(controller: any MusicControllerProtocol) {
        let now = Date()
        let action = Preferences.shared.doubleTapAction

        if action != "none" && now.timeIntervalSince(lastPrevTapTime) < doubleTapInterval {
            // Double-tap detected - first tap already sent one back, send one more = 2 total
            lastPrevTapTime = .distantPast
            switch action {
            case "restartPlaylist":
                controller.previousTrack()
            default:
                controller.previousTrack()
            }
        } else {
            lastPrevTapTime = now
            controller.previousTrack()
        }
    }

    private func launchApp(_ bundleIdentifier: String) {
        guard bundleIdentifier != "youtube" else { return }

        // For Auto mode, launch the highest-priority installed app (or Apple Music as fallback)
        let targetBundle: String
        if bundleIdentifier == "auto" {
            let priority = Preferences.shared.autoPriority
            let ignoredApps = Set(Preferences.shared.ignoredApps)
            // Find first installed non-ignored app from priority list
            var found: String?
            if !priority.isEmpty {
                for raw in priority {
                    guard !ignoredApps.contains(raw), raw != "youtube" else { continue }
                    if let app = MusicApp(rawValue: raw), app.isInstalled {
                        found = raw
                        break
                    }
                }
            }
            // Fallback: first installed non-ignored app
            if found == nil {
                for app in MusicApp.selectablePlayers where !ignoredApps.contains(app.rawValue) {
                    if app.isBrowserBased { continue }
                    if app.isInstalled { found = app.rawValue; break }
                }
            }
            targetBundle = found ?? MusicApp.appleMusic.rawValue
        } else {
            targetBundle = bundleIdentifier
        }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: targetBundle) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let cycleTargetApp = Notification.Name("ConductCycleTargetApp")
}
